import { describe, expect, test } from "bun:test";

import {
  IMPORT_MAX_ROWS,
  batches,
  normaliseEmail,
  parseContacts,
  parseCsv,
  parseVcf,
  readCsv,
} from "../../../../src/lib/contacts-import";

describe("normaliseEmail", () => {
  test("lower-cases, strips mailto and display-name wrappers", () => {
    expect(normaliseEmail("  Ayesha.Khan@Acme.CO.UK ")).toBe("ayesha.khan@acme.co.uk");
    expect(normaliseEmail("mailto:bob@x.io")).toBe("bob@x.io");
    expect(normaliseEmail("Bob <bob@x.io>")).toBe("bob@x.io");
  });
  test("rejects things that are not addresses", () => {
    for (const bad of ["", "nobody", "a@b", "a@@b.com", "a b@c.com", "a@b.c", "<script>@x.io", "x@y.io,z@y.io"]) {
      expect(normaliseEmail(bad)).toBeNull();
    }
  });
});

describe("readCsv", () => {
  test("quotes can hold the delimiter, a doubled quote and a line break", () => {
    const rows = readCsv('a,b\n"x, y","say ""hi""\nthere"\n', ",");
    expect(rows).toEqual([
      ["a", "b"],
      ["x, y", 'say "hi"\nthere'],
    ]);
  });
  test("CRLF, blank lines and a BOM are fine", () => {
    expect(readCsv("﻿a,b\r\n\r\n1,2\r\n", ",")).toEqual([
      ["a", "b"],
      ["1", "2"],
    ]);
  });
});

describe("parseCsv — real export shapes", () => {
  test("Google Contacts", () => {
    const csv = [
      "First Name,Middle Name,Last Name,Name,Organization Name,Organization Title,E-mail 1 - Label,E-mail 1 - Value,E-mail 2 - Value,Phone 1 - Value",
      "Ayesha,,Khan,Ayesha Khan,Acme Ltd,Head of Ops,Work,ayesha@acme.co.uk,ayesha@gmail.com,+44 20 7946 0000",
      "Bilal,,,,,,,bilal@x.io,,",
    ].join("\n");
    const p = parseCsv(csv);
    expect(p.format).toBe("csv");
    expect(p.rows).toEqual([
      { email: "ayesha@acme.co.uk", display_name: "Ayesha Khan", company: "Acme Ltd", title: "Head of Ops", phone: "+44 20 7946 0000" },
      { email: "bilal@x.io", display_name: "Bilal" },
    ]);
    expect(p.stats).toMatchObject({ found: 2, kept: 2, extraEmails: 1 });
  });

  test("Outlook (First/Last name, E-mail Address, Company, Mobile Phone)", () => {
    const csv = "First Name,Last Name,E-mail Address,Company,Job Title,Mobile Phone\nSara,Ali,sara@co.uk,Co Ltd,CFO,07700 900123\n";
    expect(parseCsv(csv).rows).toEqual([
      { email: "sara@co.uk", display_name: "Sara Ali", company: "Co Ltd", title: "CFO", phone: "07700 900123" },
    ]);
  });

  test("Zoho (Account Name) and semicolon-separated files", () => {
    const csv = "First Name;Last Name;Email;Account Name\nOmar;Sheikh;omar@zz.com;ZZ Group\n";
    expect(parseCsv(csv).rows).toEqual([{ email: "omar@zz.com", display_name: "Omar Sheikh", company: "ZZ Group" }]);
  });

  test("LinkedIn connections (Email Address, Position)", () => {
    const csv = "First Name,Last Name,URL,Email Address,Company,Position\nNadia,Rao,https://x,nadia@rao.org,Rao Org,Founder\n";
    expect(parseCsv(csv).rows[0]).toMatchObject({ email: "nadia@rao.org", company: "Rao Org", title: "Founder" });
  });

  test("a label column is not mistaken for the address", () => {
    const csv = "Name,E-mail Type,E-mail\nZed,Home,zed@home.io\n";
    expect(parseCsv(csv).rows).toEqual([{ email: "zed@home.io", display_name: "Zed" }]);
  });

  test("several addresses in one cell (Google uses ' ::: ')", () => {
    const csv = 'Name,E-mail 1 - Value\nMo,"mo@a.io ::: mo@b.io"\n';
    const p = parseCsv(csv);
    expect(p.rows).toEqual([{ email: "mo@a.io", display_name: "Mo" }]);
    expect(p.stats.extraEmails).toBe(1);
  });

  test("every dropped row is counted, not hidden", () => {
    const csv = "Name,Email\nA,a@x.io\nB,\nC,not-an-email\nD,A@X.IO\nE,e@x.io\n";
    const p = parseCsv(csv);
    expect(p.rows.map((r) => r.email)).toEqual(["a@x.io", "e@x.io"]);
    expect(p.stats).toMatchObject({ found: 5, kept: 2, noEmail: 1, invalidEmail: 1, duplicate: 1 });
  });

  test("a file with no e-mail column is reported as unknown, not guessed", () => {
    const p = parseCsv("Name,Phone\nA,123\nB,456\n");
    expect(p.format).toBe("unknown");
    expect(p.rows).toEqual([]);
    expect(p.stats.found).toBe(2);
  });

  test("control characters are stripped and long names are cut", () => {
    const long = "N".repeat(500);
    const p = parseCsv(`Name,Email\n"Bad\u0007 Name\nline2",x@y.io\n${long},z@y.io\n`);
    expect(p.rows[0]!.display_name).toBe("Bad Name line2");
    expect(p.rows[1]!.display_name!.length).toBe(200);
  });

  test("the cap stops a wrong file from freezing the tab", () => {
    const lines = ["Name,Email"];
    for (let i = 0; i < IMPORT_MAX_ROWS + 50; i++) lines.push(`P${i},p${i}@x.io`);
    const p = parseCsv(lines.join("\n"));
    expect(p.rows.length).toBe(IMPORT_MAX_ROWS);
    expect(p.stats.capped).toBe(true);
  });
});

describe("parseVcf", () => {
  test("vCard 3.0 with Apple/Google group prefixes, folding and escapes", () => {
    const vcf = [
      "BEGIN:VCARD",
      "VERSION:3.0",
      "N:Khan;Ayesha;;;",
      "FN:Ayesha Khan",
      "ORG:Acme\\, Ltd;Ops",
      "TITLE:Head of ",
      " Ops",
      "item1.EMAIL;type=INTERNET;type=pref:Ayesha@Acme.co.uk",
      "EMAIL;TYPE=HOME:ayesha@gmail.com",
      "TEL;type=CELL:+44 7700 900123",
      "END:VCARD",
      "BEGIN:VCARD",
      "VERSION:3.0",
      "FN:No Mail Person",
      "END:VCARD",
    ].join("\r\n");
    const p = parseVcf(vcf);
    expect(p.format).toBe("vcf");
    expect(p.rows).toEqual([
      { email: "ayesha@acme.co.uk", display_name: "Ayesha Khan", company: "Acme, Ltd", title: "Head of Ops", phone: "+44 7700 900123" },
    ]);
    expect(p.stats).toMatchObject({ found: 2, kept: 1, noEmail: 1, extraEmails: 1 });
  });

  test("a preferred address wins over the first one", () => {
    const vcf = "BEGIN:VCARD\nFN:X\nEMAIL:old@x.io\nEMAIL;PREF=1:new@x.io\nEND:VCARD\n";
    expect(parseVcf(vcf).rows[0]!.email).toBe("new@x.io");
  });

  test("vCard 2.1 quoted-printable UTF-8 names decode properly", () => {
    const vcf = "BEGIN:VCARD\nVERSION:2.1\nFN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:=C3=89lise =\n=C3=96zt=C3=BCrk\nEMAIL:elise@x.io\nEND:VCARD\n";
    expect(parseVcf(vcf).rows).toEqual([{ email: "elise@x.io", display_name: "Élise Öztürk" }]);
  });

  test("N is used when FN is missing; duplicates inside the file are counted", () => {
    const vcf = [
      "BEGIN:VCARD\nN:Rao;Nadia;;Dr;\nEMAIL:n@r.org\nEND:VCARD",
      "BEGIN:VCARD\nFN:Nadia again\nEMAIL:N@R.org\nEND:VCARD",
    ].join("\n");
    const p = parseVcf(vcf);
    expect(p.rows).toEqual([{ email: "n@r.org", display_name: "Dr Nadia Rao" }]);
    expect(p.stats.duplicate).toBe(1);
  });
});

describe("parseContacts picks the format", () => {
  test("by content, then by file name", () => {
    expect(parseContacts("BEGIN:VCARD\nFN:A\nEMAIL:a@b.io\nEND:VCARD").format).toBe("vcf");
    expect(parseContacts("Name,Email\nA,a@b.io").format).toBe("csv");
    expect(parseContacts("", "people.vcf").format).toBe("vcf");
  });
  test("an empty or unrelated text file imports nothing", () => {
    expect(parseContacts("hello world").rows).toEqual([]);
    expect(parseContacts("").rows).toEqual([]);
  });
});

describe("batches", () => {
  test("splits into request-sized chunks", () => {
    expect(batches([1, 2, 3, 4, 5], 2)).toEqual([[1, 2], [3, 4], [5]]);
    expect(batches([], 2)).toEqual([]);
  });
});
