// Package health provides dependency health checks for readiness probes.
package health

import "context"

// Checker reports the health of configured dependencies.
type Checker struct {
	deps []func(ctx context.Context) (string, bool)
}

// NewChecker creates a checker with the given dependency probes.
func NewChecker(deps ...func(ctx context.Context) (string, bool)) *Checker {
	return &Checker{deps: deps}
}

// Check evaluates all probes and returns a map of dependency name to "ok" or
// "error".
func (c *Checker) Check(ctx context.Context) map[string]string {
	result := make(map[string]string, len(c.deps))
	for _, probe := range c.deps {
		name, ok := probe(ctx)
		if ok {
			result[name] = "ok"
		} else {
			result[name] = "error"
		}
	}
	return result
}
