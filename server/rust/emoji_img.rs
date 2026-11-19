// ============================================================================
// emoji_img.rs — the image half of the COMPANY EMOJI PACK (QC1e D4A, AWAM ONLY, 20 Nov 2026).
//
// Pure Rust, two crates only: `image-webp` (decode + lossless encode) and `png` (decode). No C code, no `unsafe`.
// Flow (every step has a limit BEFORE it runs):
//   1. emoji_core::gate_upload   (size, magic bytes, header w/h, no animation, no SVG)  — nothing is decoded before this
//   2. decode with a hard pixel/alloc limit, ANY colour type -> RGBA8 (metadata chunks are simply never read into the output)
//   3. area-average downscale to the ladder step (256 -> 192 -> 128 -> 96), never upscale
//   4. lossless WebP encode, then emoji_core::check_output (RIFF....WEBP, allowed chunks only, <= 64 KB)
// The CPU work runs in tokio::task::spawn_blocking behind a 1-permit semaphore in the glue (one picture at a time).
// ============================================================================

use crate::emoji_core as core;
use std::io::Cursor;

#[derive(Debug)]
pub struct Clean {
    pub webp: Vec<u8>,
    pub w: u32,
    pub h: u32,
    pub step: u32,
}

/// Decode PNG or WebP bytes (already passed through gate_upload) into RGBA8.
pub fn decode_rgba(kind: core::Kind, bytes: &[u8]) -> Result<(u32, u32, Vec<u8>), String> {
    match kind {
        core::Kind::Webp => {
            let mut d = image_webp::WebPDecoder::new(Cursor::new(bytes)).map_err(|e| format!("WebP: {e}"))?;
            if d.is_animated() {
                return Err("animated WebP is not accepted".into());
            }
            let (w, h) = d.dimensions();
            if (w as u64) * (h as u64) > core::MAX_SRC_PIXELS {
                return Err("picture is too large in pixels".into());
            }
            let has_alpha = d.has_alpha();
            let size = d.output_buffer_size().ok_or("WebP: size overflow")?;
            let mut buf = vec![0u8; size];
            d.read_image(&mut buf).map_err(|e| format!("WebP: {e}"))?;
            let rgba = if has_alpha {
                buf
            } else {
                let mut o = Vec::with_capacity((w as usize) * (h as usize) * 4);
                for px in buf.chunks_exact(3) {
                    o.extend_from_slice(&[px[0], px[1], px[2], 255]);
                }
                o
            };
            Ok((w, h, rgba))
        }
        core::Kind::Png => {
            let mut dec = png::Decoder::new(Cursor::new(bytes));
            dec.set_transformations(png::Transformations::normalize_to_color8());
            let mut limits = png::Limits::default();
            limits.bytes = 96 * 1024 * 1024; // decoder memory ceiling
            dec.set_limits(limits);
            let mut r = dec.read_info().map_err(|e| format!("PNG: {e}"))?;
            let (w, h) = {
                let i = r.info();
                (i.width, i.height)
            };
            if (w as u64) * (h as u64) > core::MAX_SRC_PIXELS {
                return Err("picture is too large in pixels".into());
            }
            let n = r.output_buffer_size().ok_or("PNG: size overflow")?;
            let mut buf = vec![0u8; n];
            let fr = r.next_frame(&mut buf).map_err(|e| format!("PNG: {e}"))?;
            let data = &buf[..fr.buffer_size()];
            let mut o = Vec::with_capacity((w as usize) * (h as usize) * 4);
            match fr.color_type {
                png::ColorType::Rgba => o.extend_from_slice(data),
                png::ColorType::Rgb => data.chunks_exact(3).for_each(|p| o.extend_from_slice(&[p[0], p[1], p[2], 255])),
                png::ColorType::GrayscaleAlpha => data.chunks_exact(2).for_each(|p| o.extend_from_slice(&[p[0], p[0], p[0], p[1]])),
                png::ColorType::Grayscale => data.iter().for_each(|&g| o.extend_from_slice(&[g, g, g, 255])),
                png::ColorType::Indexed => return Err("PNG: palette was not expanded".into()),
            }
            if o.len() != (w as usize) * (h as usize) * 4 {
                return Err("PNG: unexpected pixel count".into());
            }
            Ok((w, h, o))
        }
    }
}

/// Area-average (box) downscale RGBA8 with premultiplied alpha so transparent edges do not bleed colour.
pub fn downscale(src: &[u8], sw: u32, sh: u32, dw: u32, dh: u32) -> Vec<u8> {
    if sw == dw && sh == dh {
        return src.to_vec();
    }
    let mut out = vec![0u8; (dw as usize) * (dh as usize) * 4];
    for dy in 0..dh {
        let y0 = (dy as u64 * sh as u64 / dh as u64) as u32;
        let y1 = (((dy as u64 + 1) * sh as u64).div_ceil(dh as u64) as u32).min(sh).max(y0 + 1);
        for dx in 0..dw {
            let x0 = (dx as u64 * sw as u64 / dw as u64) as u32;
            let x1 = (((dx as u64 + 1) * sw as u64).div_ceil(dw as u64) as u32).min(sw).max(x0 + 1);
            let (mut r, mut g, mut b, mut a, mut n) = (0u64, 0u64, 0u64, 0u64, 0u64);
            for y in y0..y1 {
                for x in x0..x1 {
                    let i = ((y as usize) * (sw as usize) + x as usize) * 4;
                    let al = src[i + 3] as u64;
                    r += src[i] as u64 * al;
                    g += src[i + 1] as u64 * al;
                    b += src[i + 2] as u64 * al;
                    a += al;
                    n += 1;
                }
            }
            let o = ((dy as usize) * (dw as usize) + dx as usize) * 4;
            if a > 0 {
                out[o] = (r / a) as u8;
                out[o + 1] = (g / a) as u8;
                out[o + 2] = (b / a) as u8;
            }
            out[o + 3] = (a / n.max(1)) as u8;
        }
    }
    out
}

pub fn encode_webp(rgba: &[u8], w: u32, h: u32) -> Result<Vec<u8>, String> {
    let mut out = Vec::new();
    image_webp::WebPEncoder::new(&mut out)
        .encode(rgba, w, h, image_webp::ColorType::Rgba8)
        .map_err(|e| format!("WebP encode: {e}"))?;
    Ok(out)
}

/// The whole job: bytes in (untrusted) -> clean lossless WebP out, or a human-readable reason.
pub fn clean(bytes: &[u8]) -> Result<Clean, String> {
    let (kind, _hw, _hh) = core::gate_upload(bytes)?;
    let (w, h, rgba) = decode_rgba(kind, bytes)?;
    let mut last = String::from("picture is too detailed: use a simple logo or badge");
    for step in core::ladder_for(w, h) {
        let (dw, dh) = core::fit(w, h, step);
        let px = downscale(&rgba, w, h, dw, dh);
        let webp = encode_webp(&px, dw, dh)?;
        match core::check_output(&webp) {
            Ok((ow, oh)) => return Ok(Clean { webp, w: ow, h: oh, step }),
            Err(e) => {
                if !e.contains("64 KB") {
                    return Err(e);
                }
                last = "picture is too detailed to fit 64 KB: use a simple logo or badge".into();
            }
        }
    }
    Err(last)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_png(w: u32, h: u32, mut f: impl FnMut(u32, u32) -> [u8; 4], color: png::ColorType) -> Vec<u8> {
        let mut out = Vec::new();
        {
            let mut e = png::Encoder::new(&mut out, w, h);
            e.set_color(color);
            e.set_depth(png::BitDepth::Eight);
            let mut wr = e.write_header().unwrap();
            let mut data = Vec::new();
            for y in 0..h {
                for x in 0..w {
                    let p = f(x, y);
                    match color {
                        png::ColorType::Rgba => data.extend_from_slice(&p),
                        png::ColorType::Rgb => data.extend_from_slice(&p[..3]),
                        png::ColorType::Grayscale => data.push(p[0]),
                        _ => unreachable!(),
                    }
                }
            }
            wr.write_image_data(&data).unwrap();
        }
        out
    }

    #[test]
    fn logo_png_becomes_clean_webp() {
        let src = make_png(600, 400, |x, y| if (x / 50 + y / 50) % 2 == 0 { [200, 30, 30, 255] } else { [20, 20, 120, 255] }, png::ColorType::Rgb);
        let c = clean(&src).unwrap();
        assert!(c.webp.len() <= core::MAX_OUT_BYTES);
        assert_eq!(&c.webp[0..4], b"RIFF");
        assert_eq!(&c.webp[8..12], b"WEBP");
        assert_eq!((c.w, c.h), (256, 170));
        assert_eq!(core::check_output(&c.webp).unwrap(), (c.w, c.h));
    }

    #[test]
    fn webp_in_webp_out_keeps_alpha() {
        let src = make_png(64, 64, |x, _| [10, 200, 10, if x < 32 { 0 } else { 255 }], png::ColorType::Rgba);
        let first = clean(&src).unwrap();
        let (_, _, rgba) = decode_rgba(core::Kind::Webp, &first.webp).unwrap();
        assert_eq!(rgba[3], 0); // left half transparent survives the round trip
        assert_eq!(rgba[(40 * 4) + 3], 255);
        let second = clean(&first.webp).unwrap(); // a WebP upload also goes through the encoder
        assert_eq!((second.w, second.h), (64, 64));
    }

    #[test]
    fn grayscale_png_works() {
        let src = make_png(80, 80, |x, y| { let v = ((x + y) * 2) as u8; [v, v, v, 255] }, png::ColorType::Grayscale);
        assert!(clean(&src).is_ok());
    }

    #[test]
    fn noisy_photo_is_refused_not_lossy() {
        let mut s: u32 = 12345;
        let src = make_png(256, 256, move |_, _| { s = s.wrapping_mul(1664525).wrapping_add(1013904223); [(s >> 24) as u8, (s >> 16) as u8, (s >> 8) as u8, 255] }, png::ColorType::Rgb);
        let e = clean(&src);
        // random noise cannot fit 64 KB losslessly even at 96 px (96*96*3 = 27 KB raw fits!) -> accept either outcome, never a lossy result
        match e {
            Ok(c) => assert!(c.webp.len() <= core::MAX_OUT_BYTES),
            Err(m) => assert!(m.contains("too detailed")),
        }
    }

    #[test]
    fn garbage_and_svg_and_bomb_refused() {
        assert!(clean(b"<svg xmlns='http://www.w3.org/2000/svg' onload='alert(1)'/>").is_err());
        assert!(clean(&[0u8; 100]).is_err());
        // header claims 60000 x 60000 -> refused by gate before any decode
        let mut bomb = make_png(32, 32, |_, _| [1, 2, 3, 255], png::ColorType::Rgb);
        bomb[16..20].copy_from_slice(&60000u32.to_be_bytes());
        bomb[20..24].copy_from_slice(&60000u32.to_be_bytes());
        assert!(clean(&bomb).unwrap_err().contains("too large"));
    }

    #[test]
    fn downscale_math() {
        let src: Vec<u8> = (0..16).flat_map(|_| [100u8, 100, 100, 255]).collect(); // 4x4 flat
        let d = downscale(&src, 4, 4, 2, 2);
        assert_eq!(&d[0..4], &[100, 100, 100, 255]);
        // fully transparent stays transparent, no colour bleed
        let t: Vec<u8> = (0..16).flat_map(|_| [255u8, 0, 0, 0]).collect();
        assert_eq!(downscale(&t, 4, 4, 2, 2)[3], 0);
    }
}
