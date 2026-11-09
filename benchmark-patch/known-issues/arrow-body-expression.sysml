// Known issue (not fixed by this patch): an arrow invocation with an inline body expression
// (collect, select, reduce, ...) loses its body on the round trip, and the importer cannot
// resolve the body's parameters. Exported as "ControlFunctions::reduce(loadPowers)".
// Workaround: write the operation out, e.g. with binary QuantityCalculations::max calls,
// or NumericalFunctions::sum / QuantityCalculations::sum for sums.
package ArrowBodyExpression {
    private import ScalarValues::*;
    private import ISQ::*;
    calc def MaxLoad {
        in loadPowers : PowerValue[1..*];
        return : PowerValue = loadPowers->ControlFunctions::reduce { in a : PowerValue; in b : PowerValue; QuantityCalculations::max(a, b) };
    }
}
