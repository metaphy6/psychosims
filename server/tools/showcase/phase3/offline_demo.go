package main

import (
	"fmt"
	"time"

	"psychosims.dev/server/internal/offline"
	"psychosims.dev/server/internal/ownership"
)

func offlineDemo(path string) error {
	r := newReport("Offline race resolution")
	r.line("This demo resolves a race between two pending offline actions on the same patient.")
	r.line("")

	leaseExpiry := time.Now().UTC().Add(time.Hour)
	lease := &ownership.Record{
		PatientID:      "p1",
		AccountID:      "acct-A",
		State:          ownership.StateOwned,
		LeaseExpiresAt: &leaseExpiry,
	}

	a := offline.RaceAction{AccountID: "acct-A", PatientID: "p1", Kind: offline.ActionCure, ClientTime: time.Now().UTC().Add(-time.Minute), LeaseVersion: 1}
	b := offline.RaceAction{AccountID: "acct-B", PatientID: "p1", Kind: offline.ActionTransfer, ClientTime: time.Now().UTC(), LeaseVersion: 1}

	result := offline.ResolveRace(a, b, lease, time.Now().UTC())

	r.h2("Race inputs")
	r.line("- Account A: `%s` (%s)", a.AccountID, a.Kind)
	r.line("- Account B: `%s` (%s)", b.AccountID, b.Kind)
	r.line("- Lease expires at: `%s`", leaseExpiry.Format(time.RFC3339))
	r.line("")

	r.h2("Resolution")
	r.code(fmt.Sprintf("winner = %s\nloser = %s\nreason = %s", result.WinnerAccountID, result.LoserAccountID, result.Reason))

	return r.write(path)
}
