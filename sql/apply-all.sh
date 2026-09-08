#!/usr/bin/env bash
# ANEXOMAIL — saari SQL files sahi tarteeb mein apply + result table.
# Use: bash sql/apply-all.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

ORDER=$(cat <<'LIST'
sql/phase_leo_memory.sql
sql/phase12a_mail_prediction.sql
sql/phase17_ai_studio.sql
sql/phase18_ai_automation.sql
sql/phase19_ai_billing.sql
sql/phase20_ai_knowledge.sql
sql/phase21_billing_platform.sql
sql/phase22_integrations.sql
sql/phase23_settings.sql
sql/phase24_analytics.sql
sql/phase25_admin.sql
sql/phase26_security.sql
sql/phase27_perf.sql
sql/phase28_handoff.sql
sql/phase28_revenue.sql
sql/phase30_release.sql
sql/phase31_ai_credits.sql
sql/phase32_trial.sql
sql/phase33_polar_checkout.sql
sql/phase35_payment_safety.sql
sql/phase36_state_sync.sql
sql/phase37_movein_ops.sql
sql/phase39_movein_fixes.sql
sql/phase40_evidence_truth.sql
sql/phase43_annual_billing_lock.sql
sql/phase44_polar_ids_v2.sql
sql/phase45_founder_identity.sql
sql/phase46_pricing_v5.sql
sql/phase47_glitch_crm_alert.sql
sql/phase48_storage_quota.sql
sql/phase49_absm_billing_mesh.sql
sql/phase49b_hotfix_random_token.sql
sql/phase50_polar_rust_payment.sql
sql/phase51_polar_payment_hardening.sql
sql/phase52_mail_launch.sql
sql/phase54_mail_ingest_org_fix.sql
sql/phase55_founder_single_inbox.sql
sql/phase57_mail_schema_heal.sql
sql/phase58_mail_contract_final.sql
sql/phase59_account_lifecycle.sql
sql/phase56_mailbox_final.sql
sql/phase60_family_chat_workspace.sql
anexochat/sql/anexochat_phase03_message_engine.sql
anexochat/sql/anexochat_phase07_cinema_video.sql
anexochat/sql/anexochat_phase10a_call_engine.sql
anexochat/sql/anexochat_phase10b_8k_video.sql
anexochat/sql/anexochat_phase11_attachments.sql
anexochat/sql/anexochat_phase11b_attachment_flag.sql
anexochat/sql/anexochat_phase12_continuity.sql
anexochat/sql/phase13_15_file_engine.sql
anexochat/sql/phase16_18_file_truth_safety.sql
anexochat/sql/phase19_22_device_safety_work.sql
anexochat/sql/phase23_promise_engine.sql
anexochat/sql/phase24_decision_ledger.sql
anexochat/sql/phase24a_account_integrity.sql
anexochat/sql/phase25_27_timeline_health_provenance.sql
anexochat/sql/phase28_receipts.sql
anexochat/sql/phase29_email_to_chat.sql
anexochat/sql/phase30_chat_to_email.sql
anexochat/sql/phase31_file_context.sql
anexochat/sql/videocall_phase31_call_record.sql
anexochat/sql/videocall_phase31a_lightspeed.sql
LIST
)

LOG=/root/anexomail-sql-apply.log
: > "$LOG" && chmod 600 "$LOG"

echo "DATABASE PREFLIGHT"
if ! bash sql/run.sh --check 2>&1 | tee -a "$LOG"; then
  echo
  echo "STOP: database connection green nahi; kisi SQL file ko apply nahi kiya."
  echo "Upar asli shared error hai — 59 files ko ghalat RED mark nahi kiya gaya."
  exit 1
fi

FROM="${1:-}"; [ "$FROM" = "--from" ] && FROM="${2:-}"
SKIPPING=0; [ -n "$FROM" ] && SKIPPING=1

G=0; R=0; RED_LIST=""
for f in $ORDER; do
  if [ "$SKIPPING" -eq 1 ]; then
    if [ "$f" = "$FROM" ]; then SKIPPING=0; else echo "SKIP   $f"; continue; fi
  fi
  if [ ! -f "$f" ]; then echo "RED    $f (missing)" | tee -a "$LOG"; R=$((R+1)); RED_LIST="$RED_LIST $f"; break; fi

  out="$(bash sql/run.sh "$f" 2>&1)"; rc=$?
  echo "=== $f ===" >> "$LOG"; printf '%s\n' "$out" >> "$LOG"
  if [ "$rc" -eq 0 ]; then
    echo "GREEN  $f"; G=$((G+1))
  else
    echo "RED    $f"; printf '%s\n' "$out"
    R=$((R+1)); RED_LIST="$RED_LIST $f"
    echo "STOP: pehli failing phase par ruk gaya; baqi phases abhi run nahi huin."
    echo "RESUME: bash sql/apply-all.sh --from $f"
    break
  fi
done


echo
echo "GREEN=$G  RED=$R"
[ "$R" -gt 0 ] && { echo "RED FILES:$RED_LIST"; echo "detail: $LOG"; }
[ "$R" -eq 0 ] && echo "ALL SQL GREEN"
exit "$R"
