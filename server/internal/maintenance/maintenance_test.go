package maintenance

import (
	"testing"
	"time"
)

func TestPolicyBounds(t *testing.T) {
	p := DefaultPolicy()
	if err := p.Validate(); err != nil {
		t.Fatal(err)
	}
	for _, edit := range []func(*Policy){func(p *Policy) { p.BatchSize = 0 }, func(p *Policy) { p.BatchSize = 1001 }, func(p *Policy) { p.RetryGrace = 0 }, func(p *Policy) { p.RetryGrace = 31 * 24 * time.Hour }, func(p *Policy) { p.ReceiptRetention = time.Hour }, func(p *Policy) { p.ReceiptRetention = 366 * 24 * time.Hour }} {
		c := p
		edit(&c)
		if c.Validate() == nil {
			t.Fatal("accepted unsafe policy")
		}
	}
}
