"""Sage file for Homework Assignment 2, SDP 2018, Mastermath.

Your program should be written in this file. You may write as many
functions as you like, but you should follow the instructions in the
PDF file. The functions you are required to write should behave
exactly as specified.

Two useful functions are provided for you in this file:

- run_csdp, which runs CSDP from Sage, and

- read_csdp_solution, which reads the solution file generated by CSDP
  and returns the solution matrices.

Take a look at function float_sos below to see how these two functions
are used. If you have any doubts, remarks, suggestions or corrections,
write a post on our ELO forum.

"""

import subprocess
from scipy.misc import imread, imsave


def run_csdp(filename, solfile):
    """Run CSDP and return True on success, False on failure.

    INPUT:

    - filename -- string with the input file name for csdp.

    - solfile -- string with the name of the file where the solution
      will be stored.

    EXAMPLE:

        if run_csdp('foo.sdpa', 'foo.sol'):
            print 'Success'
        else:
            raise RuntimeError('Failed to solve sdp')

    IMPORTANT:

    For this function to work, the CSDP solver must be callable from
    the command line and its directory must be included in the
    system's path.

    """
    try:
        out = subprocess.check_output([ 'csdp', filename, solfile ])
    except:
        return False

    return True


def read_csdp_solution(filename, block_sizes):
    """Return matrices comprising solution of problem in CSDP format.

    INPUT:

    - filename -- name of solution file.

    - block_sizes -- list with the sizes of the blocks in the correct
      order. As with the SDPA format, a negative number indicates a
      diagonal block.

    RETURN VALUE:

    This function returns a list of the same length as block_sizes
    with the corresponding solution blocks. A nondiagonal block is a
    matrix over RDF. A diagonal block is a vector over RDF.

    EXAMPLE:

    See function float_sos.

    """
    # Make a list of the solution matrices, initialized to zero.
    ret = []
    for s in block_sizes:
        if s < 0:
            ret.append(vector(RDF, -s))
        else:
            ret.append(matrix(RDF, s))

    # Then read the solution.
    with open(filename, 'r') as infile:
        # Discard first line.
        infile.readline()

        # Read the matrices.
        for line in infile:
            if line[0] == '2':
                words = line.split()

                block = int(words[1]) - 1
                i = int(words[2]) - 1
                j = int(words[3]) - 1

                if block < 0 or block >= len(block_sizes):
                    raise RuntimeError('invalid block index')

                if i < 0 or i >= block_sizes[block] \
                   or j < 0 or j >= block_sizes[block]:
                    raise RuntimeError('invalid matrix position')

                ret[block][i, j] = ret[block][j, i] = RDF(words[4])

    return ret


def float_sos(p):
    """Return sos representation of univariate polynomial p.

    If p is not a sum of squares, then this function raises the
    ValueError exception. Otherwise, the function returns a list of
    polynomials giving the sos representation of p. The sos
    representation returned uses floating-point numbers.

    Use this function to see how to run CSDP and read the solution
    using the functions above.

    EXAMPLES:

    Here is an example of a polynomial that is a sum of squares:

        sage: load('hma2.sage')
        sage: x = PolynomialRing(RDF, 'x').gen()
        sage: p = x^4 - 3*x^3 - x^2 + 15
        sage: float_sos(p)
        [-0.6551908751612898*x^2 - 5.636867756363169e-17*x + 3.872983346207417,
         -0.7430582026375091*x^2 + 2.0186843973671262*x,
         0.13634304015422885*x^2]
        sage: sum(q^2 for q in _)
        x^4 - 3.0*x^3 - 0.9999999999999991*x^2 - 4.3662989890336238e-16*x + 15.000000000000002

    And here an example of a polynomial that is not an sos:

        sage: p = x^4 - 1
        sage: float_sos(p)
        [...]
        ValueError: polynomial is not SOS, says CSDP

    """
    if p.degree() % 2 != 0:
        raise ValueError('polynomial has odd degree')
    
    # Generate the SDPA file with the problem.
    out = open('foo.sdpa', 'w')

    out.write('%d\n' % (p.degree() + 1))
    out.write('1\n')
    out.write('%d\n' % (1 + p.degree() // 2))

    # Right-hand side.
    for a in p.list():
        out.write('%f ' % a)

    out.write('\n')

    # Constraints for each degree.
    for deg in xrange(p.degree() + 1):
        for i in xrange(1 + p.degree() // 2):
            j = deg - i

            if j >= 0 and j <= p.degree() // 2 and i <= j:
                out.write('%d 1 %d %d 1.0\n'
                          % (deg + 1, i + 1, j + 1))

    # Run CSDP.
    out.close()

    if not run_csdp('foo.sdpa', 'foo.sol'):
        raise ValueError('polynomial is not SOS, says CSDP')

    # Read the solution.
    sol = read_csdp_solution('foo.sol', [ 1 + p.degree() // 2 ])
    X = sol[0]

    try:
        U = X.cholesky()
    except:
        raise ValueError('solution is not psd, oops!')

    PR = PolynomialRing(RDF, 'x')
    x = PR.gen()
    foo = [ x^k for k in xrange(1 + p.degree() // 2) ]
    vx = vector(PR, foo)

    return list(U.transpose() * vx)


def normalize_matrix(A):
    """Normalize matrix elements to [-1, 1]."""

    l = min(A.list())
    u = max(A.list())

    if l == u:
        if l <= 127:
            return matrix(RDF, A.nrows(), A.ncols(),
                          lambda i, j: -1)
        else:
            return matrix(RDF, A.nrows(), A.ncols(),
                          lambda i, j: 1)
    
    return matrix(RDF, A.nrows(), A.ncols(),
                  lambda i, j: 2 * ((A[i, j] - l) / (u - l)) - 1)


def sdp_filter(in_filename, out_filename, lda, r, block_size = 10,
               border_size = 2, nrounds = 30):
    """Apply deblurring sdp filter to image.

    INPUT:

    - in_filename -- name of input image.

    - out_filename -- name of output image.

    - lda -- lambda parameter.

    - r -- pixels (a, b) and (ap, bp) are considered neighbors if 
      max { |a - ap|, |b - bp| } <= r.

    - block_size -- size of block for image segmentation, in number of
      pixels.

    - border_size -- size of border around a block, in number of
      pixels.

    - nrounds -- how many times the randomized rounding procedure
      should be run.

    """
    # Read the image. The matrix returned has real numbers in the
    # interval [0, 255].
    A = matrix(RDF, imread(in_filename, flatten = True))

    # Matrix with resulting binary image, to be filled by you.
    R = matrix(ZZ, A.nrows(), A.ncols())
    
    ########
    #
    # Here should come your code. It should assemble the final image
    # in the matrix R. Each pixel has a value of either 0 (black) or
    # 255 (white).
    #
    # IMPORTANT:
    #
    # Recall that the matrix A you read has numbers in [0, 255]. Our
    # approach expects numbers in the interval [-1, 1]. To get that,
    # you normalize each block before processing it. If B is the
    # block, use the function normalize matrix:
    #
    # C = normalize_matrix(B)
    # 
    ########

    # Save the final image.
    imsave(out_filename, R)


def interval_minimum(p, a, b, filename):
    """Write SDP whose optimal is minimum of p on [a, b].

    This function writes to a file called filename a semidefinite
    program in SDPA format whose optimal value is the minimum of the
    polynomial p on the interval [a, b]. Notice p can have even or odd
    degree.

    INPUT:

    - p -- a polynomial over RDF.

    - a, b -- endpoints of interval, a < b.

    - filename -- name of file for SDPA output.

    """
    pass


# Local variables:
# mode: python
# End:
