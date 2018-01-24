<#
.Synnopsis
 A few general tests for the Truth Table Generator
#>

# load the module that contains everything
using module .\PoshBoolAlgebra.psm1

describe "Conjuntion operations with two operands" {

    it "does a conjunction with A and B - Part I" {
        $wt = New-TruthTable -Formula "A AND B"
        $wt.Rank -eq 1 | should be $true
    }

    it "does a conjunction with A and B  - Part II" {
        $wt = New-TruthTable -Formula "A AND B"
        $wt.GetLength(0) -eq 4 | should be $true
    }

    it "does a conjunction with A and B  - Part III" {
        $wt = New-TruthTable -Formula "A AND B" -RawValues
        $wt[3,2] | should be $true
    }
}

describe "Disjunction with two operands" {

    it "does a disjunction with A or B - Part I" {
        $wt = New-TruthTable -Formula "A OR B"
        $wt.Rank -eq 1 | should be $true
    }

    it "does a disjunction with A or B  - Part II" {
        $wt = New-TruthTable -Formula "A OR B" 
        $wt.GetLength(0) -eq 4 | should be $true
    }

    it "does a disjunction with A and B  - Part III" {
        $wt = New-TruthTable -Formula "A OR B" -RawValues 
        $wt[1,2] | should be $true
    }

    it "does a disjunction with A and B  - Part IV" {
        $wt = New-TruthTable -Formula "A OR B" -RawValues
        $wt[2,2] | should be $true
    }

    it "does a disjunction with A and B  - Part V" {
        $wt = New-TruthTable -Formula "A OR B" -RawValues
        $wt[3,2] | should be $true
    }
}

describe "a little more special operations" {

    it "does a conjunction with two negations" {
        $wt = New-TruthTable -Formula "NOT A AND NOT B" -RawValues
        $wt[0,2] -eq $true -and $wt[1,2] -eq $false| should be $true
    }
}

describe "Braket operations" {

    it "does a conjunction and a disjunction with brakets" {
        # A = 1, B = 0, C = 1 must result to true
        $wt = New-TruthTable -Formula "A AND (B OR C)" -RawValues
        $wt[6,3] | should be $true
    }
}

describe "IMP operations" {

    it "does a implication with two operands" {
        # A = 1, B = 0, C = 1 must result to true
        $wt = New-TruthTable -Formula "(A IMP B)" -RawValues
        $wt[2,2] | should be $false
    }

    it "does a implication with two negated operands" {
        $wt = New-TruthTable -Formula "(NOT B IMP NOT C)" -RawValues
        $wt[1,2] | should be $false
    }
}

describe "EQV operations" {

    it "does a equivalent with two operands" {
        # A = 1, B = 0, C = 1 must result to true
        $wt = New-TruthTable -Formula "(A EQV B)" -RawValues
        $wt[0,2] -And $wt[3,2] | should be $true
    }
}

describe "error checking operations" {

        # if testing for Should throw command under test has to be a scriptblock 
        it "test if a logical term does start with an operator" {
            { New-TruthTable -Formula "AND B)" -RawValues } | Should throw "A logical term cannot start with an operator"
        }

        it "test if a logical term missing a second variable" {
            { New-TruthTable -Formula "A AND" } | Should throw  "A logical term must terminate with either a variable or a braket"
        }
    }

# Some simple ad hoc tests
# New-TruthTable -Formula "A OR  B" -Verbose
# New-TruthTable -Formula "A AND B" -Verbose
# New-TruthTable -Formula "NOT A AND NOT B" -Verbose 
# New-TruthTable -Formula "NOT A AND B" -Verbose
# New-TruthTable -Formula "A OR  B AND NOT C" -Verbose
# New-TruthTable -Formula "A OR (B AND C)" -Verbose -HtmlOutput
# New-TruthTable -Formula "A IMP B" -Verbose 
# New-TruthTable -Formula "(NOT B IMP NOT C)" -Verbose 
# New-TruthTable -Formula "NOT (A OR B)" -Verbose 
# New-TruthTable -Formula "NOT (A AND B)" -Verbose 

# Error testing
# New-TruthTable -Formula "A BLA B"
# New-TruthTable -Formula "AND B"

# New-TruthTable -Formula "A AND" 

# New-TruthTable -Formula "C OR (A AND B"

# New-TruthTable -Formula "A EQV B"