---
title: Introduction to Calculus
category: Sciences
subject: Mathematics
level: GCE Advanced Level
topic: Calculus
difficulty: Advanced
creatorId: academia-compiler
creatorName: Academia
tags: [GCE A-Level, Mathematics, Calculus]
---

## Limits and Continuity

**Calculus** is the branch of mathematics concerned with continuous change. It rests on one foundational idea: the **limit** — what value a function approaches as its input gets closer and closer to some point, even if it never actually reaches it.

### Understanding a Limit

Consider the function:

```
f(x) = (x² - 1) / (x - 1)
```

At x = 1, this function is undefined (division by zero). But as x gets closer and closer to 1 from either side, f(x) gets closer and closer to 2. We write:

```
lim (x→1) f(x) = 2
```

This is the essence of a limit: describing behavior *near* a point, not necessarily *at* it.

### Continuity

A function is **continuous** at a point if three conditions all hold:

1. The function is defined at that point.
2. The limit exists at that point.
3. The limit equals the function's actual value at that point.

A function with any break, jump, or hole in its graph is **discontinuous** at that location.

[IMAGE: a graph showing a smooth continuous curve next to a curve with a visible jump discontinuity, for comparison]

## Differentiation

**Differentiation** finds the rate at which a function's output changes relative to its input — geometrically, the slope of the tangent line at any point on its curve.

### The Derivative, from First Principles

The derivative of f(x) is defined as:

```
f'(x) = lim (h→0) [f(x + h) - f(x)] / h
```

This measures the slope of a line connecting two points on the curve as those two points get infinitely close together.

### Common Differentiation Rules

- **Power rule:** if f(x) = xⁿ, then f'(x) = n·xⁿ⁻¹
- **Sum rule:** the derivative of a sum is the sum of the derivatives
- **Product rule:** for f(x) = u(x)·v(x), f'(x) = u'v + uv'
- **Chain rule:** for a composite function f(g(x)), the derivative is f'(g(x))·g'(x)

### Worked Example

Differentiate f(x) = 3x² + 5x - 7:

```
f'(x) = 6x + 5
```

Each term is differentiated using the power rule, and constants (like -7) disappear since their rate of change is always zero.

## Integration

**Integration** is, in many ways, the reverse of differentiation. Instead of finding a rate of change, it finds a total accumulated quantity — most famously, the area under a curve.

### Indefinite Integrals

The indefinite integral reverses the power rule:

```
∫ xⁿ dx = xⁿ⁺¹ / (n + 1) + C
```

The **+C** represents an unknown constant, since differentiating any constant gives zero — meaning many functions could share the same derivative.

### Definite Integrals and Area

A **definite integral** calculates the exact area between a curve and the x-axis, between two boundary points a and b:

```
∫ₐᵇ f(x) dx
```

This is evaluated by finding the antiderivative F(x), then computing F(b) − F(a).

### Worked Example

Find the area under f(x) = 2x between x = 1 and x = 3:

```
∫₁³ 2x dx = [x²]₁³ = (3² - 1²) = 8
```

The area under the line between those two points is exactly 8 square units.

### Practice Questions

1. Evaluate lim (x→2) (x² - 4)/(x - 2).
2. Differentiate f(x) = 4x³ - 2x² + x - 9.
3. Find ∫ (6x² - 4x + 1) dx.
4. Calculate the definite integral of f(x) = x² from x = 0 to x = 2, and state what this value physically represents.
