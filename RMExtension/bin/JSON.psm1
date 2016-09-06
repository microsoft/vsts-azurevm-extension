<#
    Simple JSON (de)serializer

    WARNING: This code is needed in PS 2.0 becase the ConvertTo/From-JSON cmdlets are
             not available in that version. Prefer the cmdlets over this module when
             possible.

    Adapted to PowerShell from Douglas Crockford's reference implementation
    (https://github.com/douglascrockford/JSON-js/blob/master/json2.js and 
    https://github.com/douglascrockford/JSON-js/blob/master/json_parse.js)

    This module defines a JSON custom object containing two methods: stringify and parse.

        $JSON.stringify(value)

            value - A hashtable, array or simple object (date, string or number; dates
                    are serialized as strings in ISO format).

            The replacer and space parameters in the reference implementation are not 
            supported; neither is the toJSON method.
    
            This method produces a JSON text from the given value.

            Values that are not supported will not be serialized. Such values in hashtables 
            will be dropped; in arrays they will be replaced with null.

        $JSON.parse(text)
            This method parses a JSON text to produce a hashtable, array or simple object.
            It can throw a SyntaxError exception.

            The reviver parameter in the reference implementation implementation is not 
            supported.

            The implementation of parse is based in json_parse.js, to avoid to use of the 
            eval function.

    NOTE: This module is used on PowerShell 2.0. Be sure to test any changes to this module using PS 2.0.
#>

$ErrorActionPreference = 'stop'

Set-StrictMode -Version latest

#
# U - Helper to convert a Unicode numeric code to a character.
#
# This is needed because PowerShell doesn't support unicode escape sequences; the short name
# helps usage of the function within a string, e.g. "$(U 0x007F)" to represent "\u007F".
#
function U
{
    param([int] $Code)
 
    if (0 -le $Code -and $Code -le 0xFFFF)
    {
        return [char] $Code
    }
 
    if (0x10000 -le $Code -and $Code -le 0x10FFFF)
    {
        return [char]::ConvertFromUtf32($Code)
    }
 
    throw "Unsupported character code $Code"
}
 
#
# The JSON object itself
#
$JSON = New-Object PSObject 

# *****************************************************************************
# *                                                                           *
# *                               stringify                                   *
# *                                                                           *
# *****************************************************************************

#
# Regex to match number types
#
$script:numberTypes = [regex] '^(System.SByte)|(System.Byte)|(System.Int16)|(System.UInt16)|(System.Int32)|(System.UInt32)|(System.Int64)|(System.UInt64)|(System.Single)|(System.Double)|(System.Decimal)$'

#
# Regex to match characters that need to be escaped
#
$script:escapable = New-Object Regex "[\\""'$(U 0x00)-$(U 0x1f)$(U 0x7f)-$(U 0x9f)$(U 0x00ad)$(U 0x0600)-$(U 0x0604)$(U 0x070f)$(U 0x17b4)$(U 0x17b5)$(U 0x200c)-$(U 0x200f)$(U 0x2028)-$(U 0x202f)$(U 0x2060)-$(U 0x206f)$(U 0xfeff)$(U 0xfff0)-$(U 0xffff)]", 'Singleline'

#
# Table of character substitutions
#
$script:meta = @{
    "`b" = '\b'
    "`t" = '\t'
    "`n" = '\n'
    "`f" = '\f'
    "`r" = '\r'
    '"'  = '\"'
    '\' = '\\'
}

#
# quote
#
function quote([string] $str) {
    # If the string contains no control characters, no quote characters, and no
    # backslash characters, then we can safely slap some quotes around it.
    # Otherwise we must also replace the offending characters with safe escape
    # sequences.
    if ($script:escapable.Match($str)) {
        '"' + $script:escapable.replace($str, {
            param([System.Text.RegularExpressions.Match] $match)

            $c = $script:meta[$match.Value]

            if ($c) {
                $c
            } else {
                '\u{0:x4}' -f [int][char]$match.Value
            }
        }) + '"' 
    } else {
        '"' + $s + '"'
    }
}

#
# str - produce a string from $holder[$key]
#
function str($key, $holder) {
    $value = $holder[$key]

    if ($value -eq $null)
    {
        return 'null'
    }

    $type = $value.GetType()

    switch ($type) {
        { $_.FullName -eq 'System.String' } {
            return quote $value
        }

        { $_.FullName -eq 'System.Char' } {
            return quote ([string]$value)
        }

        { $_.FullName -match $script:numberTypes } {
            # JSON numbers must be finite. Encode non-finite numbers as null.
            $stringValue = $value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
            if ($stringValue -eq 'NaN') {
                return 'null'
            } else {
                return $stringValue
            }
        }

        { $_.FullName -eq 'System.Boolean' } {
            return $value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }

        { $_.FullName -eq 'System.DateTime' } {
            if ($value.Kind -eq [System.DateTimeKind]::Local) {
                $value = $value.ToUniversalTime()
            }
            return '"' + $value.ToString('s') + 'Z"'
        }

        { $_.FullName -eq 'System.DateTimeOffset' } {
            return '"' + $value.UtcDateTime.ToString('s') + 'Z"'
        }

        { $_.IsArray } {
            # Make an array to hold the partial results of stringifying this value.
            $partial = @()

            # Stringify every element. Use null as a placeholder for non-JSON values.
            $length = $value.Length
            for ($i = 0; $i -lt $length; $i++) {
                $s = str $i $value
                if ($s) {
                    $partial += $s
                } else {
                    $partial += 'null'
                }
            }

            # Join all of the elements together, separated with commas, and wrap them in
            # brackets.
            if ($partial.Length -eq 0) {
                $v = '[]'
            } else {
                $v = '[' + ($partial -join ',') + ']'
            }
            return $v
        }

        { $_.FullName -eq 'System.Collections.Hashtable' } {
            # Make an array to hold the partial results of stringifying this value.
            $partial = @()

            # Stringify every element.
            foreach ($k in $value.Keys | sort) {
                $v = str $k  $value
                if ($v) {
                    $partial += (quote $k) + ': ' + $v
                }
            }

            # Join all of the member texts together, separated with commas,
            # and wrap them in braces.
            if ($partial.Length -eq 0) {
                $v = '{}'
            } else {
                $v = '{' + ($partial -join ',') + '}'
            }
            return $v
        }
    }
}

#
# stringify
#
Add-Member -InputObject $JSON ScriptMethod stringify {
    param([object] $value)

    # Make a fake root object containing our value under the key of ''.
    # Return the result of stringifying the value.
    str '' @{'' = $value}
}

# *****************************************************************************
# *                                                                           *
# *                                parse                                      *
# *                                                                           *
# *****************************************************************************

$script:text = $null
$script:at = 0      # The index of the current character
$script:ch = $null  # The current character
$script:escapee = @{
    '"' =  '"'
    '\' = '\'
    '/' =  '/'
    b   =  "`b"
    f   =  "`f"
    n   =  "`n"
    r   =  "`r"
    t   =  "`t"
}

function error($m) {
    # Call error when something is wrong.
    throw "SyntaxError: $m [$script:text]@$script:at"
}

function next($c) {
    # If a c parameter is provided, verify that it matches the current character.
    if ($c -and $c -ne $script:ch) {
        error ("Expected '" + $c + "' instead of '" + $ch + "'")
    }

    # Get the next character. When there are no more characters, return the empty string.
    if ($script:at -ge $script:text.Length)
    {
        $script:ch = ''
    } else {
        $script:ch = $script:text[$script:at]
        $script:at += 1
    }
}

function number() {
    # Parse a number value.
    $string = ''
    $isInteger = $true

    if ($script:ch -eq '-') {
        $string = '-'
        next '-'
    }
    while ($script:ch -match '\d') {
        $string += $script:ch
        next
    }
    if ($script:ch -eq '.') {
        $isInteger = $false
        $string += '.'
        for (next; $script:ch -match '\d'; next) {
            $string += $script:ch
        }
    }
    if ($script:ch -eq 'e' -or $script:ch -eq 'E') {
        $isInteger = $false
        $string += $script:ch
        next
        if ($script:ch -eq '-' -or $script:ch -eq '+') {
            $string += $script:ch
            next
        }
        while ($script:ch -match '\d') {
            $string += $script:ch
            next
        }
    }
    $number = 0
    if ($isInteger) {
        if (![System.Int64]::TryParse($string, [ref] $number)) {
            error 'Bad number'
        }
    } else {
        if (![System.Double]::TryParse($string, [ref] $number)) {
            error 'Bad number'
        }
    }
    return $number
}

function string {
    # Parse a string value.
    $string = ''

    # When parsing for string values, we must look for " and \ characters.
    if ($script:ch -eq '"') {
        for (next; $script:ch; next) {
            if ($script:ch -eq '"') {
                next
                return $string
            }
            if ($script:ch -eq '\') {
                next
                if ($script:ch -eq 'u') {
                    $uffff = 0;
                    for ($i = 0; $i -lt 4; $i += 1) {
                        next
                        $hex = 0
                        if (![int]::TryParse($script:ch, [System.Globalization.NumberStyles]::AllowHexSpecifier, [System.Globalization.NumberFormatInfo]::InvariantInfo, [ref] $hex)) {
                            break
                        }
                        $uffff = $uffff * 16 + $hex
                    }
                    $string += [char]::ConvertFromUtf32($uffff)
                } elseif ($script:escapee[[string]$script:ch]) {
                    $string += $script:escapee[[string]$script:ch]
                } else {
                    break
                }
            } else {
                $string += $script:ch;
            }
        }
    }
    error 'Bad string'
}

function white {
    #  Skip whitespace.
    while ($script:ch -and [int][char]$script:ch -le [int][char]' ') {
        next
    }
}

function word {
    # true, false, or null.
    switch ($script:ch) {
        't' {
            next 't'
            next 'r'
            next 'u'
            next 'e'
            return $true
        }
        'f' {
            next 'f'
            next 'a'
            next 'l'
            next 's'
            next 'e'
            return $false
        }
        'n' {
            next 'n'
            next 'u'
            next 'l'
            next 'l'
            return $null
        }
    }
    error ("Unexpected '" + $script:ch + "'")
}

function array {
    # Parse an array value.
    $arrayList = New-Object System.Collections.ArrayList

    if ($script:ch -eq '[') {
        next '['
        white
        if ($script:ch -eq ']') {
            next ']'
            return ,$arrayList.ToArray() # empty array
        }
        while ($script:ch) {
            $arrayList.Add((value)) > $null
            white
            if ($script:ch -eq ']') {
                next ']'
                return ,$arrayList.ToArray()
            }
            next ','
            white
        }
    }
    error 'Bad array'
}

function object {
    # Parse an object value.
    $object = @{}

    if ($script:ch -eq '{') {
        next '{'
        white
        if ($script:ch -eq '}') {
            next '}'
            return $object # empty object
        }
        while ($script:ch) {
            $key = string
            white
            next ':'
            if ($object.ContainsKey($key)) {
                error 'Duplicate key "' + $key + '"'
            }
            $object[$key] = value
            white
            if ($script:ch -eq '}') {
                next '}'
                return $object
            }
            next ','
            white
        }
    }
    error 'Bad object'
}

function value {
    # Parse a JSON value. It could be an object, an array, a string, a number,
    # or a word.
    white
    switch ($script:ch) {
        '{' {
            return object
        }
        '[' {
            $array = array # use an intermediate variable to force unraveling on the array (PS > 2 doesn't unravel it)
            return ,$array
        }
        '"' {
            $string = string
            if ($string -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d*)?Z$')
            {
                return [System.DateTimeOffset]::Parse($string)
            }
            return $string
        }
        { $_ -match '[\d-]' } {
            return number
        }
        default {
            return word
        }
    }
}

#
# parse
#
Add-Member -InputObject $JSON ScriptMethod parse {
    param([string] $source)

    $script:text = $source
    $script:at = 0
    $script:ch = ' '
    $result = value
    white
    if ($script:ch) {
        error 'Syntax error'
    }
    if ($result -eq $null) {
        $null
    } elseif ($result.GetType().IsArray) {
        return ,$result
    } else {
        return $result
    }
}

#
# Module exports
#
Export-ModuleMember -Function U -Variable JSON
