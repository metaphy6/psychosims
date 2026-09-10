package receipts

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/outcomes"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/schemas"
)

// Verdict is saved in the acceptance transaction and returned unchanged on
// replay. It describes server-derived rewards, never a client's ledger claim.
type Verdict struct {
	ProfileVersion int    `json:"profile_version,omitempty"`
	RewardStatus   string `json:"reward_status"`
	Reason         string `json:"reward_reason,omitempty"`
	CertificateID  string `json:"certificate_id,omitempty"`
	XP             int    `json:"xp_awarded,omitempty"`
	StudyPoints    int    `json:"study_points_awarded,omitempty"`
	CashMicros     int64  `json:"cash_micros_awarded,omitempty"`
}

// ConfigureCertifiedOutcomes must be called only while composing an unused
// service. A nil catalog leaves every receipt unproven. Revocation is loaded
// from the operator's catalog configuration when composition is recreated.
func (s *Service) ConfigureCertifiedOutcomes(c *outcomes.Catalog, p config.CureRewardPolicy, enabled bool) error {
	if err := p.Validate(); err != nil {
		return err
	}
	s.outcomes = c
	s.rewardPolicy = p
	s.rewardsEnabled = enabled
	return nil
}

func (s *Service) AcceptanceVerdict(ctx context.Context, accountID, receiptID string) (Verdict, error) {
	var body []byte
	err := s.store.QueryRowContext(ctx, `SELECT accepted_verdict FROM session_authorizations WHERE id=$1 AND account_id=$2 AND consumed_at IS NOT NULL`, receiptID, accountID).Scan(&body)
	if err == sql.ErrNoRows {
		return Verdict{}, api.NewNotFound("accepted receipt not found")
	}
	if err != nil {
		return Verdict{}, err
	}
	// Legacy accepted receipts predate durable verdicts and were never paid.
	// Their unknown original profile version is omitted instead of guessed.
	if len(body) == 0 {
		return Verdict{RewardStatus: "held_unproven"}, nil
	}
	var v Verdict
	if err = json.Unmarshal(body, &v); err != nil {
		return Verdict{}, err
	}
	return v, nil
}

func (s *Service) applyCertified(ctx context.Context, tx *sql.Tx, prof *profile.PrimitiveProfile, r *schemas.SessionReceipt, certificateID, catalogHash string) (Verdict, error) {
	v := Verdict{RewardStatus: "held_unproven"}
	if s.outcomes == nil || catalogHash != s.outcomes.ArtifactSHA256() || !s.outcomes.Match(certificateID, *r) {
		return v, nil
	}
	v.CertificateID = certificateID
	v.RewardStatus = "certified_unrewarded"
	var now time.Time
	if err := tx.QueryRowContext(ctx, `SELECT clock_timestamp()`).Scan(&now); err != nil {
		return Verdict{}, err
	}
	var already bool
	if err := tx.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM certified_cures WHERE account_id=$1 AND case_id=$2)`, prof.AccountID, r.StartState.CaseID).Scan(&already); err != nil {
		return Verdict{}, err
	}
	var count int
	var xp, study, cash int64
	var last sql.NullTime
	p := s.rewardPolicy
	if err := tx.QueryRowContext(ctx, `SELECT COUNT(*),COALESCE(SUM(xp),0),COALESCE(SUM(study_points),0),COALESCE(SUM(cash_micros),0),MAX(accepted_at) FROM certified_cures WHERE account_id=$1 AND accepted_at>$2`, prof.AccountID, now.Add(-p.Window)).Scan(&count, &xp, &study, &cash, &last); err != nil {
		return Verdict{}, err
	}
	switch {
	case already:
		v.Reason = "already_cured"
	case !s.rewardsEnabled:
		v.Reason = "economy_disabled"
	case last.Valid && now.Sub(last.Time) < p.MinimumInterval:
		v.Reason = "cooldown"
	case count >= p.MaxCuresPerWindow || xp+int64(p.XP) > int64(p.XPPerWindow) || study+int64(p.Study) > int64(p.StudyPerWindow) || cash+p.CashMicros > p.CashPerWindow:
		v.Reason = "window_budget"
	case prof.XP < 0 || prof.StudyPoints < 0 || prof.CashMicros < 0 || int64(prof.XP)+int64(p.XP) > 2147483647 || int64(prof.StudyPoints)+int64(p.Study) > 2147483647 || prof.CashMicros > 9_000_000_000_000_000-p.CashMicros:
		v.Reason = "balance_limit"
	default:
		if s.validator.ledger == nil {
			return Verdict{}, api.NewServiceUnavailable("certified reward ledger unavailable")
		}
		v.RewardStatus = "certified"
		v.XP = p.XP
		v.StudyPoints = p.Study
		v.CashMicros = p.CashMicros
		credits := []schemas.LedgerEvent{}
		debits := []schemas.LedgerEvent{}
		for _, amount := range []struct {
			currency schemas.CurrencyType
			micros   int64
		}{{schemas.CurrencyXP, int64(p.XP) * 1_000_000}, {schemas.CurrencyStudy, int64(p.Study) * 1_000_000}, {schemas.CurrencyCash, p.CashMicros}} {
			if amount.micros == 0 {
				continue
			}
			if int64(int(amount.micros)) != amount.micros {
				return Verdict{}, fmt.Errorf("reward exceeds runtime integer width")
			}
			h := sha256.Sum256([]byte(r.ID + "\x00" + string(amount.currency)))
			key := "cure:" + hex.EncodeToString(h[:])
			ev := schemas.LedgerEvent{Kind: "certified_cure", Currency: amount.currency, AmountMicros: int(amount.micros), IdempotencyKey: key, ReasonKey: "rewards.certified_cure"}
			credits = append(credits, ev)
			ev.Kind = "reward_source"
			ev.AmountMicros = -ev.AmountMicros
			debits = append(debits, ev)
		}
		if len(credits) > 0 {
			const sourceAccount = "system:certified-rewards"
			if _, err := tx.ExecContext(ctx, `INSERT INTO accounts(id) VALUES($1) ON CONFLICT DO NOTHING`, sourceAccount); err != nil {
				return Verdict{}, err
			}
			if err := s.validator.ledger.Append(ctx, tx, prof.AccountID, credits); err != nil {
				return Verdict{}, err
			}
			if err := s.validator.ledger.Append(ctx, tx, sourceAccount, debits); err != nil {
				return Verdict{}, err
			}
		}
		prof.XP += v.XP
		prof.StudyPoints += v.StudyPoints
		prof.CashMicros += v.CashMicros
	}
	if !already {
		if _, err := tx.ExecContext(ctx, `INSERT INTO certified_cures(account_id,case_id,receipt_id,certificate_id,accepted_at,xp,study_points,cash_micros) VALUES($1,$2,$3,$4,$5,$6,$7,$8)`, prof.AccountID, r.StartState.CaseID, r.ID, certificateID, now, v.XP, v.StudyPoints, v.CashMicros); err != nil {
			return Verdict{}, err
		}
	}
	// A proven cure is terminal even when policy withholds rewards. This keeps
	// cooldown/kill-switch decisions from turning completed cases into farms.
	if _, err := tx.ExecContext(ctx, `UPDATE ownership_records SET state='cured',version=version+1,lease_expires_at=NULL WHERE patient_id=$1 AND account_id=$2`, r.PatientID, prof.AccountID); err != nil {
		return Verdict{}, err
	}
	return v, nil
}
