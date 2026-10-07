# PSScriptAnalyzer rules for this repository. Three rules are left out on purpose:
#   PSAvoidUsingWriteHost         the bootstrap talks to a person at a terminal. Write-Host is
#                                 what gives each [INFO], [ OK ], [WARN] and [ERROR] line its colour
#   PSUseShouldProcessForStateChangingFunctions
#                                 -Plan already covers every change through Invoke-Step, so a second
#                                 -WhatIf system would only duplicate it
#   PSUseSingularNouns            names such as Install-WingetPackages read naturally for a script
#                                 that is never published as a module
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSingularNouns'
    )
}
