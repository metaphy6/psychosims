package main

import (
	"context"
	"fmt"
	"time"

	"psychosims.dev/server/internal/ownership"
	"psychosims.dev/server/internal/timeutil"
)

func ownershipDemo(path string) error {
	r := newReport("Ownership lease + memory class guard")
	r.line("This demo claims a patient and enforces a memory-class transition guard.")
	r.line("")

	ctx := context.Background()
	repo := ownership.NewInMemoryRepository()
	svc := ownership.NewService(repo, timeutil.RealClock{})

	if err := svc.Claim(ctx, "p1", "acct-1", 1, ownership.MemoryClassStateless); err != nil {
		return err
	}

	rec, _ := repo.Get(ctx, "p1")
	r.h2("Claimed patient")
	r.code(fmt.Sprintf("state = %s\naccount = %s\nmemory_class = %s", rec.State, rec.AccountID, rec.MemoryClass))

	// Stateless patients cannot be hospitalized.
	err := svc.Transition(ctx, "p1", "acct-1", ownership.StateOwned, ownership.StateHospitalized, 2)
	r.h2("Hospitalization attempt (stateless)")
	if err != nil {
		r.code(fmt.Sprintf("blocked = true\nerror = %v", err))
	} else {
		r.code("blocked = false")
	}

	leaseExpiry := time.Now().UTC().Add(30 * time.Second)
	rec.LeaseExpiresAt = &leaseExpiry
	// Directly update in-memory record for demo purposes.
	if err := repo.Transition(ctx, "p1", "acct-1", ownership.StateOwned, ownership.StateOwned, 2); err != nil {
		return err
	}

	return r.write(path)
}
