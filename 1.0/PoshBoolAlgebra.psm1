<#
 .Synopsis
 Truth Table Generator (TTG) - Version 1.0
 .Description
 Returns either plain text or html tables based on a logical term
  .Notes
  Author: Peter Monadjemi - pm@activetraining.de
  
  Last Update: 11/1/17
  Last Update: 11/5/17
  Last Update: 11/6/17
  Last Update: 11/11/17

 > Works with brakets
 > Works with Negation before brakets (de Morgan-mode)
 > Supported operators: AND, OR, NOT, IMP
 > Error detection while evaluating
 > Supported operator: EQV (-A v B) ^ (A v -B)
 
 TODOS:
 > Time measurement
 > CSS Formating for HTML table output
#>

Set-StrictMode -Version Latest

# Defines all allowed token types
enum TokenType
{
    CloseBraket
    OpenBraket
    Operator
    Variable
}

# Represents a single token
class WTToken
{
    [TokenType]$Type
    [String]$Name
    [Bool]$Value
    
    # Constructor without any arguments
    WTToken()
    {
        $this.Name = "Empty"
        $this.Value = $null
    }

    # Constructor with two arguments
    WTToken([TokenType]$Type, [String]$Name)
    {
        $this.Type = $Type
        $this.Name = $Name
    }
}

# List of allowed operators
$Operatorlist = @("AND", "OR", "NOT", "IMP", "EQV")

<#
 .Synopsis
 Outputs a decimal number in its binary representation
#>
function ConvertTo-Binary
{
    param([Parameter(ValueFromPipeline=$true)][Int]$Number, [Int]$Digits = 3, [Switch]$Display, [Switch]$DisplayHeader)
    begin
    {
        if ($DisplayHeader)
        {
            @(65..(65+$Digits-1)).ForEach{[Char]$_} -join  "`t"
        }
    }
    process
    {
        $Output = @()
        for ($i=$Digits-1; $i -ge 0; $i--)
        {
            if(($Number / [Math]::Pow(2, $i)) -ge 1)
            {
                $Output += 1
                $Number -= [Math]::Pow(2, $i)
            }
            else
            {
                $Output += 0
            }
        }
        if ($Display)
        {
            $Output -join "`t"
        }
        else
        {
            $Output
        }
    }
 }

<#
 .Synopsis
 Outputs a truth table based on an boolean two dimensional array
#>
function Out-TruthTable
{
    [CmdletBinding(DefaultParametersetName="Default")]
     param([Parameter(ValueFromPipeline=$true, Mandatory=$true)][Bool[,]]$Values,
           [Parameter(ParametersetName="Bool")][Switch]$BoolOutput,
           [Parameter(ParametersetName="Html")][Switch]$HtmlOutput)
    $TotalOutput = @()
    for($i = 0; $i -lt $Values.GetLength(0); $i++)
    {
        $OutputLine = ""
        for($j = 0; $j -lt $Values.GetLength(1); $j++)
        {
            if ($BoolOutput)
            {
                $OutputLine += "$($Values[$i, $j])`t"
            }
            else
            {
                $OutputLine += "$([Byte]$Values[$i, $j])`t"
            }
        }
        $OutputLine
        $Props = [Ordered]@{}
        for($j=0;$j-lt ($OutputLine -split "`t").Count - 2; $j++)
        {
            # $Outputline contains boolean value/tab char pairs
            $Props += @{[Char][Byte]($j+65)=$OutputLine[$j*2]}
        }
        # Append result column
        $Props += @{"R"=$OutputLine[-2]}
        $TotalOutput += [PSCustomObject]$Props
    }
    if ($HtmlOutput)
    {
        $TotalOutput | ConvertTo-Html -Fragment
    }
}

<#
 .Synopsis
 Evaluates a token list and returns a single result
#>

function Evaluate-Tokenlist
{
    # Important: May not work when the variable had been already defined inside ISE because the full type name also contains the ps1 file path
    # and is not compatible with a different ps1 path
    param([System.Collections.Generic.List[WTToken]]$Tokenlist)
    [Bool]$FirstOperand = $true
    [Bool]$Result = $false
    [Bool]$Operand = $false
    [Bool]$NotMode = $false
    [String]$LastOperator = ""

    # Process all tokens
    foreach($Token in $Tokenlist)
    {
        switch($Token.Type)
        {
            "Variable" {
                if ($FirstOperand)
                {
                    $Result = $Token.Value
                    if ($NotMode)
                    {
                        $NotMode = $false
                        $Result = -not $Result
                    }
                    $FirstOperand = $false
                }
                else
                {
                    $Operand = $Token.Value
                    if ($NotMode)
                    {
                        $NotMode = $false
                        $Operand = -not $Operand
                    }
                    switch($LastOperator)
                    {
                        "AND" {
                            $Result = $Result -and $Operand

                        }
                        "OR" {
                            $Result = $Result -or $Operand
                        }
                        "IMP" {
                            # -A v B
                            $LastOperator = "OR"
                            $Result = -NOT $Result
                            $Result = $Result -OR $Operand
                        }
                        "EQV" {
                            # (-A v B) ^ (A v -B)
                            $TempResult1 = -NOT $Result 
                            $TempResult1 = $TempResult1 -OR $Operand
                            $TempResult2 = $Result -OR -NOT $Operand
                            $Result = $TempResult1 -AND $TempResult2
                            # $LastOperator = "AND"
                            # throw "This operator is not implemented yet"
                        }
                    }
                }
            }

            "Operator" {
                # Operator except NOT not allowed as first term element
                if ($Token.Name -ne "NOT" -and $FirstOperand)
                {
                    throw "A logical term cannot start with an operator"
                }
                if ($Token.Name -eq "NOT")
                {
                    
                    $NotMode = !$NotMode
                }
                else
                {
                    $LastOperator = $Token.Name
                }
            }

        }
    }
    $Result
    Write-Verbose "Evaluation of tokenlist returns $Result"
}


<#
 .Synopsis
 Creates a truth table based on a tokenlist
#>
function Create-TruthTable
{
    [CmdletBinding()]
    param([WTToken[]]$TokenList,[Switch]$HtmlOutput, [Switch]$RawValues)

    [Bool]$FirstOpMode = $true
    [Bool]$NotMode = $false
    [Bool]$DeMorganMode = $false
    [Bool]$Operand = $false
    [Bool]$OpMode = $false
    $Operator = ""
    [Bool]$Result = $false
    $ResultValues = @()

    # Get the number of columns by getting the number of variables with unique names
    $AllVariables = $TokenList | Where-Object Type -eq "Variable" | Sort-Object -Property Name -Unique
    # The number of variables can be one too so we have to make it an array anyway
    $VariableCount = @($AllVariables).Count
    
    for ($i = 0; $i -lt [Math]::Pow(2, $VariableCount); $i++)
    {
        $FirstOpMode = $true
        $BinValues = ConvertTo-Binary $i -Digits $VariableCount

        $OperationStack = New-Object -TypeName System.Collections.Stack
        $ExecutionList = New-Object -TypeName System.Collections.Generic.List[WTToken]

        Write-Verbose "*** Verarbeite Zeilenwert $($BinValues -join "`t")"
        # Place the values into variables
        for($j = 0; $j -lt @($BinValues).Count; $j++)
        {
            # Assing the value to a variable as a boolean value
            $AllVariables[$j].Value = [Bool]$BinValues[$j]
        }
            
        # Process all tokens
        foreach($Token in $TokenList)
        {
            # differentiate between the token types
            switch ($Token.Type)
            {
                "OpenBraket" {
                    Write-Verbose "Processing an Open braket"
                    # Check for negation before the braket
                    if ($NotMode)
                    {
                        # a close braket will switch signs and operators
                        $DeMorganMode = $true
                        $NotMode = $false
                    }
                    # Push current execution list on the stack and start new execution list
                    $OperationStack.Push($ExecutionList)
                    # TODO: comment in when everything else works
                    # $ExecutionList = [System.Collections.Generic.List[WTToken]]::new()
                    $ExecutionList = New-Object -TypeName System.Collections.Generic.List[WTToken]
                    # Start a new token list
                    $FirstOpMode = $true
                    continue
                }

                "CloseBraket" {
                    Write-Verbose "Processing a Close Braket"
                    # Check for DeMorganMode
                    if ($DeMorganMode)
                    {
                        $DeMorganMode = $false
                        # Switch sign of every variable and switch disjunction/conjunction
                        foreach($Token in $ExecutionList)
                        {
                            switch ($Token.Type)
                            {
                                "Variable" {
                                    $Token.Value = -Not $Token.Value
                                    continue
                                }
                                "Operator" {
                                    # Variable not necessary but used anyway
                                    $Operator = $Token.Name
                                    if ($Operator -eq "OR")
                                    {
                                        $Operator = "AND"
                                    }
                                    elseif ($Operator -eq "AND")
                                    {
                                        $Operator = "OR"
                                    }
                                    continue
                                }
                            }
                        }
                    }
                    # Get value of current execution list and use the result as current operand
                    $Operand = Evaluate-Tokenlist -Tokenlist $ExecutionList

                    # Get the last execution list from the stack
                    $ExecutionList = $OperationStack.Pop()

                    # Add Operand value to current execution list - the variable name is always X
                    $ExecutionList.Add((New-Object WTToken -ArgumentList "Variable", "X" -Property @{Value=$Operand}))
                }

                "Operator" {
                    $Operator = $Token.Name
                    Write-Verbose "Processing Operator $Operator"
                    $ExecutionList.Add($Token)
                    continue
                }
                
                "Variable" {
                    Write-Verbose "Processing Variable $($Token.Name) with value $($Token.Value)"
                    $ExecutionList.Add($Token)
                    continue
                }
            }
        }

        $ResultValues += Evaluate-Tokenlist -Tokenlist $ExecutionList
    }

    # Attatch the result column to the two dimensional array
    $BinResults = New-Object -TypeName "Bool[,]" -ArgumentList ([Math]::Pow(2, $VariableCount)), ($VariableCount+1)

    for ($i = 0; $i -lt [Math]::Pow(2, $VariableCount); $i++)
    {
        $BinValues = ConvertTo-Binary $i -Digits $VariableCount
        for($j = 0; $j -lt @($BinValues).Count; $j++)
        {
            $BinResults[$i, $j] = $BinValues[$j]
        }
        $BinResults[$i, @($BinValues).Count] = $ResultValues[$i]
    }
    if (!$RawValues)
    {
        Out-TruthTable -Values $BinResults -HtmlOutput:$HtmlOutput
    }
    else
    {
        # return the whole array and not a single value
        ,$BinResults
    }
}

<#
 .Synopsis
 Check if current input word is an operator
#>
function Test-Operator
{
    param([Parameter(Mandatory=$true)][String]$Operator)
    # Script scope modifier is not necessary because of read access - but better for readability
    # For the pester script it has to be global???
    return $Operator -in $Script:Operatorlist
}

<#
 .Synopsis
 Creating a new truth table based on a text formula
 .Notes
 THIS IS THE FUNCTION TO CALL
#>
function New-TruthTable
{
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][String]$Formula,
          [Switch]$HtmlOutput,
          [Switch]$RawValues)
    # internal variables
    $BraketCount = 0
    $CharacterMode = $false
    $LastCharacter = ""
    $InputWord = ""
    # Remove extra white spaces from the formula
    $Formula = $Formula -replace "(\s{2,})"," "
    # Make everything upper case
    $Formula = $Formula.ToUpper()
    # Split the formula into tokens
    $TokenList = @()
    switch($Formula.ToCharArray())
    {
        # Blank?
        { [Byte]$_ -eq 32 } {
            # Is it a variable?
            if ($CharacterMode -and $InputWord.Length -eq 1)
            {
                Write-Verbose "Variable: $InputWord"
                $TokenList += (New-Object -TypeName WTToken -ArgumentList ("Variable", $InputWord) -Property @{Value=$false})
            } elseif ($CharacterMode)
            {
                # longer than 1 char - but it can't be an operator because that has already been checked
                throw "The operator $InputWord does not work  - please try one of these operators $($Script:OperatorList -join ",")"
            }
            $InputWord = ""
            $CharacterMode = $false
            continue
        }
        # Character?
        { [Byte]$_ -in @(65..91) } {
            # Store character in a variable - variable can only be one character each
            $LastCharacter = $_
            if (!$CharacterMode)
            {
                $CharacterMode = $true
            }
            $InputWord += $_
            # Check if current word is already an operator?
            if (Test-Operator -Operator $InputWord)
            {
                $CharacterMode = $false
                $TokenList += (New-Object -Typename WTToken -Property @{Type="Operator";Name=$InputWord})
                Write-Verbose "Operator: $InputWord"
                $InputWord = ""
                # Clear last character to prevent side effects
                $LastCharacter = ""
            }
            continue
        }

        # Open Braket
        { [Byte]$_ -eq 40 } {
            Write-Verbose "Opening Braket"
            $BraketCount++
            $TokenList += (New-Object -Typename WTToken -Property @{Type="OpenBraket" }) 
            continue
        }

        # Close Bracket
        { $_ -eq 41 } {

            Write-Verbose "Closing Braket"
            $BraketCount--
            # Offene Variable �bernehmen, wenn vorhanden

            # Ist eine Variable vorhanden?
            if ($InputWord.Length -ne 1)
            {
                throw "Formula can not be evaluated - must be variable before closing braket."
            }
            
            Write-Verbose "Variable: $InputWord"
            $TokenList += (New-Object -TypeName WTToken -ArgumentList ("Variable", $InputWord) -Property @{Value=$false})
            $TokenList += (New-Object -Typename WTToken -Property @{Type="CloseBraket" }) 
            $CharacterMode = $false
            # Clear last character to prevent side effects
            $LastCharacter = ""
         
            continue
        }
    }
    # Process last character
    
    # is last character an alphabetical character?
    if ($LastCharacter -in @(65..91))
    {
        # Character is part of a variable name
        Write-Verbose "Variable: $LastCharacter"
        $TokenList += (New-Object -Typename WTToken -Property @{Type="Variable";Name=$LastCharacter;Value=$false})
    }

    # Check if last token was an operator
    if ($TokenList[-1].Type -eq "Operator")
    {
        throw "A logical term must terminate with either a variable or a braket"
    }


    # Check for matching brakets
    if ($BraketCount -gt 0)
    {
        throw "Error in formular - please check the brakets"
    }
    Create-TruthTable -TokenList $TokenList -HtmlOutput:$HtmlOutput -RawValues:$RawValues
}


Set-Alias -Name NTT -Value New-TruthTable

# Export only one function and every alias
Export-ModuleMember -Function New-TruthTable -Alias *

