"""Numerically stable symmetric Givens rotation.
Given `a` and `b`, return `(c, s, ρ)` such that

    [ c  s ] [ a ] = [ ρ ]
    [ s -c ] [ b ] = [ 0 ].
"""
function sym_givens(a :: Float64, b :: Float64)
	#
	# Modeled after the corresponding Matlab function by M. A. Saunders and S.-C. Choi.
	# http://www.stanford.edu/group/SOL/dissertations/sou-cheng-choi-thesis.pdf
	# D. Orban, Montreal, May 2015.

  if b == 0.0
    a == 0.0 && (c = 1.0) || (c = sign(a));  # In Julia, sign(0) = 0.
    s = 0.0;
    ρ = abs(a);

  elseif a == 0.0
    c = 0.0;
    s = sign(b);
    ρ = abs(b);

  elseif abs(b) > abs(a)
    t = a / b;
    s = sign(b) / sqrt(1.0 + t * t);
    c = s * t;
    ρ = b / s;  # Computationally better than d = a / c since |c| <= |s|.

  else
    t = b / a;
    c = sign(a) / sqrt(1.0 + t * t);
    s = c * t;
    ρ = a / c;  # Computationally better than d = b / s since |s| <= |c|
  end

  return (c, s, ρ)
end


"""Find the real roots of the quadratic

    q(x) = q₂ x² + q₁ x + q₀,

where q₂, q₁ and q₀ are real. Care is taken to avoid numerical
cancellation. Optionally, `nitref` steps of iterative refinement
may be performed to improve accuracy. By default, `nitref=1`.
"""
function roots_quadratic(q₂ :: Float64, q₁ :: Float64, q₀ :: Float64;
                         nitref :: Int=1)
  # Case where q(x) is linear.
  if q₂ == 0.0
    if q₁ == 0.0
      q₀ == 0.0 && return [0.0] || return Float64[]
    else
      return [-q₀ / q₁]
    end
  end

  # Case where q(x) is indeed quadratic.
  rhs = sqrt(eps(Float64)) * q₁ * q₁
  if abs(q₀ * q₂) > rhs
    ρ = q₁ * q₁ - 4.0 * q₂ * q₀
    ρ < 0.0 && return Float64[]
    d = -0.5 * (q₁ + copysign(sqrt(ρ), q₁))
    roots = [d / q₂, q₀ / d]
  else
    # Ill-conditioned quadratic.
    roots = [-q₁ / q₂, 0.0]
  end

  # Perform a few Newton iterations to improve accuracy.
  for k = 1 : 2
    root = roots[k]
    for it = 1 : nitref
      q = (q₂ * root + q₁) * root + q₀
      dq = 2.0 * q₂ * root + q₁
      dq == 0.0 && continue
      root = root - q / dq
    end
    roots[k] = root
  end
  return roots
end


"""Given a trust-region radius `radius`, a vector `x` lying inside the
trust-region and a direction `d`, return `σ` > 0 such that

    ‖x + σ d‖ = radius

in the Euclidean norm. If known, ‖x‖² may be supplied in `xNorm2`.
"""
function to_boundary(x :: Vector{Float64}, d :: Vector{Float64},
                     radius :: Float64; xNorm2 :: Float64=0.0)
  radius > 0 || error("radius must be positive")

  # σ is the positive root of the quadratic
  # ‖d‖² σ² + 2 xᵀd σ + (‖x‖² - radius²).
  xd = dot(x, d)
  dNorm2 = dot(d, d)
  xNorm2 == 0.0 && (xNorm2 = dot(x, x))
  (xNorm2 <= radius * radius) || error("x lies outside of the trust region")
  roots = roots_quadratic(dNorm2, 2 * xd, xNorm2 - radius * radius)
  return maximum(roots)
end
