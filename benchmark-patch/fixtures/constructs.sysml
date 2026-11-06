package Variants {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    doc /* It's a test of the doc's apostrophes. */
    calc def A { in x : PowerValue; in y : PowerValue; return r : PowerValue = x - y; }
    calc def B { in x : PowerValue; return : PowerValue; }
    calc def C { doc /* c */ in x : Real; return r : Real; }
    calc def D { in x : Real; x * 2 }
    part def P { port p : Q; port q : Q; attribute w : PowerValue; }
    port def Q;
    part outer : P {
        part inner : P;
        bind p = inner.p;
        connection c connect q to inner.q;
        attribute v : PowerValue = A(1 [W], 2 [W]);
        calc k : A { in x = 1 [W]; in y = 2 [W]; }
        attribute v2 : PowerValue = k.r;
    }
    package V {
        view v1 : StandardViewDefinitions::GeneralView { expose outer::**; }
        view v2 : StandardViewDefinitions::GeneralView { expose outer::*; }
    }
    requirement r1 { subject s : P; }
    package T { satisfy r1 by Variants::outer; }
}
