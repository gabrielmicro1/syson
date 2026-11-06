// Known issue (not fixed by this patch): a calculation body that ends in a bare result
// expression loses its first operand on the round trip. Exported as "* 2".
// Workaround: declare the result with a named or typed return, e.g.
//     calc def D { in x : Real; return : Real = x * 2; }
package ResultExpression {
    private import ScalarValues::*;
    calc def D { in x : Real; x * 2 }
    calc def E { in a : Real; a * 2 }
}
