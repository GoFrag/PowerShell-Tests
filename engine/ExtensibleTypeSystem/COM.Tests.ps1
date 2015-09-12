Describe -tags 'Innerloop', 'DRT' "ComMisc" {
#    <summary>Misc test cases for COM interop</summary>
## Ensure that you can call GetType() on a COM object that doesn't implement the type interface
	It "Should have been able to get COM type name" {
        $objTrans = New-Object -ComObject "NameTranslate"
        $objNT = $objTrans.GetType()
		'__ComObject' | Should Be $objNT.Name
	}
}
Describe -tags 'Innerloop', 'P1' "ExposeBug220261" {
    #    <summary>Test cases COM interop: regression for Win7:220261</summary>
    # the bug seemed easier to reproduce if we use some memory first
    BeforeAll {
    $useSomeMemory = 1..8Mb
    }

    #
    # Get-member would hit the bug
    #
    for ($i = 0; $i -lt 32; $i++)
    {
        # The Drives property would hit the bug
        It "Scripting.FileSystemObject properly report drives (iteration $i)" {
            $comObj = new-object -com "Scripting.FileSystemObject"
            $comObj | gm > $null
            $comObj.Drives.Count | Should BeGreaterThan 0
        }
    }
}
Describe -tags 'Innerloop', 'DRT' "FinalRelease929020" {
#  <Test>
#    <TestType>DRT</TestType>
#    <summary>test case trapping InvalidComObjectException </summary>
#  </Test>


    BeforeAll {
        $obj = new-object -com  "Scripting.Dictionary"
        $obj.Add("A", "Apple")
        [Runtime.InteropServices.Marshal]::FinalReleaseComObject([__ComObject]$obj) | out-null
    }

	It "trap was not hit" {
        try
        {
            $obj.Add("B", "Banana")
            throw "OK"
        }
        catch
        {
		    $_.FullyQualifiedErrorId | Should be "System.Runtime.InteropServices.InvalidComObjectException"
        }
	}
}

Describe -tags 'Innerloop', 'DRT' "GetMember" {

    BeforeAll {
        $fs = new-object -com "scripting.filesystemobject"
        $members = @($fs | get-member)
        $properties = @($fs | get-member -membertype properties)
    }
    AfterAll {
        $fs = $null
        $members = $null
        $properties = $null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }

    #    <summary>test cases COM interop</summary>
	It "Com object get-member call returns correct value" {
		$members.Length | Should Be 27
	}

    foreach ($member in $members)
    {
        $name = $member.Name
        It "${name}.ToString() has proper value" {
            $member.ToString() | should match $name
        }
    }

	It "Com object get-member can get properties" {
		$properties.Length | Should Be 1
	}

    foreach ($property in $properties)
    {
        It "${name}.ToString() has proper type" {
            $property.TypeName |Should Match "Com"
        }
    }
}

Describe -tags 'Innerloop', 'DRT' "COM MethodInvoke" {
#    <summary>test cases COM interop</summary>

#Create COM object
    BeforeAll {
        $obj = new-object -com  "Scripting.FileSystemObject"
        #Create File using COM method.
        $filename = "${TestDrive}\COMMethodAndPropertyFile.txt"
        $fileobj = $obj.CreateTextFile($filename, $true)
    }

    AfterAll {
        $obj.DeleteFile($filename)
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }

	It "Unable to create text file using COM" {
		$fileobj | Should Not BeNullOrEmpty
	}

    It "The file should actually exist" {
        "$filename" | Should exist
    }

    It "Closing the file via com should not throw" {
        #Close the file using COM Method.
        { $fileobj.Close() } |Should not throw
    }

	It "File Size created using COM object is not zero" {
        $fileobj = $obj.GetFile($filename)
		$fileobj.Size | Should Be 0
	}
}
Describe -tags 'Innerloop', 'DRT' "MethodOverLoadDefinitions" {
#    <summary>test cases COM interop</summary>
    BeforeAll {
        $obj = new-object -com  "Scripting.FileSystemObject"
        $method = $obj.PSObject.Methods["BuildPath"]
        $x = $method.OverLoadDefinitions
        $expected = "string BuildPath (string, string)"
    }

	It "COM Method OverLoadDefinitions doesn't return same value" {
		$x | Should Be $expected
	}

    AfterAll {
        $obj = $null
        $method = $null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}
Describe -tags 'Innerloop', 'DRT' "ObjectParameters" {
#  <Test>
#    <TestType>DRT</TestType>
#    <summary>test cases COM interop</summary>
#  </Test>

    BeforeAll {
        function GetParameter()
        {
            $returnValue = new-object system.management.automation.psobject 32
            $returnValue | add-member -Force noteproperty name value > $null
            It "Note sticks as it should" {
                $returnValue.Name | Should Be "value"
            }
            return $returnValue
        }

        function AssertResult($result, $strmessage)
        {
            It "32 present after $strmessage" {
                $result | Should Be 32
            }
            It "PSObject has been stripped after $strmessage" {
                $result.Name | Should Be $null
            }
        }
        $obj = new-object -com  "MshComTest.ObjectParameter"
    }



#VariantMethod
$result = $obj.VariantMethod( (GetParameter) )
AssertResult $result "VariantMethod"

#VariantParameterizedPropertyTestParameter
$result = $obj.VariantParameterizedPropertyTestParameter( (GetParameter) )
AssertResult $result "VariantParameterizedPropertyTestParameter"

#VariantParameterizedPropertyTestPut
$obj.VariantParameterizedPropertyTestPut( "ignored" ) = GetParameter
$result = $obj.VariantParameterizedPropertyTestPut( "ignored" )
AssertResult $result "VariantParameterizedPropertyTestParameter"

#VariantProperty
$obj.VariantProperty = GetParameter
$result = $obj.VariantProperty
AssertResult $result "VariantProperty"

## Verify that binding rules unwrap PSObject arguments
$results = powershell -noprofile -command {
    $obj = (new-object -com  "MshComTest.ObjectParameter").PSOBject.BaseObject
    $testDate = Get-Date -Format "yyyy-MM-dd" (Get-Date).ToUniversalTime()

    function foo { $obj.MethodInputType($args[0]) }
    foo "Test Date"
    foo $testDate
}

	It "Should have been a string initially" {
		8 | Should Be $results[0]
	}
	It "Should have been a string via reference" {
		8 | Should Be $results[1]
	}

## Verify that type coersion works - We're passing in a string array to
## an argument that expects a single string.
$obj = new-object -com  "Scripting.FileSystemObject"
$result = $obj.GetFile((,"$pshome\powershell.exe"))
	It "NoName-a9ab6015-56dd-4a15-ab58-a134dcf4e822" {
		"powershell.exe" | Should Be $result.name
	}

[bool] $boolean = $true
[string] $string = "Hello"
$customObject = New-Object PSObject
$customObject = $customObject | Add-Member IntProperty 1234 -Passthru

## Verify that binding restrictions are limited to types
$obj = new-object -com  "MshComTest.ObjectParameter"
$r1 = $obj.VariantMethod($boolean)
$r2 = $obj.VariantMethod($string)
$r3 = $obj.VariantMethod($customObject.IntProperty)

	It "Should have done Bool conversion" {
		"True" | Should Be $r1
	}
	It "Should have done String conversion" {
		"Hello" | Should Be $r2
	}
	It "Should have done Int conversion via PSCustomObject" {
		"1234" | Should Be $r3
	}

}
Describe -tags 'Innerloop', 'DRT' "OptionalArguments" {
#  <Test>
#    <TestType>DRT</TestType>
#    <summary>test cases COM interop</summary>
#  </Test>


    BeforeAll {
        $obj = new-object -com  "MshComTest.OptionalArguments"
    }

### OptionalsOnlyMethod1
	It "OptionalsOnlyMethod1 should have 1 Parameter" {
        $result = $obj.OptionalsOnlyMethod1()
		$result | Should Be 1
	}
	It "OptionalsOnlyMethod1 have 2 Parameters" {
        $result = $obj.OptionalsOnlyMethod1(2)
		$result | Should Be 2
	}

    It "Should throw appropriately" {
        try {
            $obj.OptionalsOnlyMethod1(1,2)
            Throw "OK"
        }
        catch {
            $_.Exception.GetType().FullName | Should Be "System.Management.Automation.MethodException"
        }
    }

	It "OptionalsAlsoMethod1 One Optional Parameter" {
        $result = $obj.OptionalsAlsoMethod1(3)
		$result | Should Be 4
	}

	It "OptionalsAlsoMethod1 No Optional Parameter" {
        $result = $obj.OptionalsAlsoMethod1(3,2)
		$result | Should Be 5
	}

    It "OptionalsAlsoMethod with 3 arguments throws correctly" {
        try {
            $obj.OptionalsAlsoMethod1(1,2,4)
            Throw "OK"
        }
        catch {
            $_.Exception.GetType().FullName | Should Be "System.Management.Automation.MethodException"
        }
	}

    It "OptionalsAlsoMethod1 without arguments throws correctly" {
        try {
            $obj.OptionalsAlsoMethod1()
            Throw "OK"
        }
        catch {
            $_.Exception.GetType().FullName | Should Be "System.Management.Automation.MethodException"
        }
    }

	It "OptionalOnlyProperty1 No Parameters" {
        $result = $obj.OptionalOnlyProperty1()
		$result | Should Be 1
	}
	It "OptionalOnlyProperty1 1 Parameter" {
        $result = $obj.OptionalOnlyProperty1(2)
		$result | Should Be 2
	}

    It "OptionalOnlyProperty with 2 arguments throws correctly" {
        try {
            $obj.OptionalOnlyProperty1(1,2)
            Throw "OK"
        }
        catch {
            $_.Exception.GetType().FullName | Should Be "System.Management.Automation.GetValueInvocationException"
        }
    }


### OptionalOnlyProperty1 Setting
	It "OptionalOnlyProperty1 Parameter can be set" {
        $obj.OptionalOnlyProperty1()=2
        $result = $obj.OptionalOnlyProperty1()
		$result | Should Be 4
	}
	It "OptionalOnlyProperty1 1 Parameter after set" {
        $result = $obj.OptionalOnlyProperty1(2)
		$result | Should Be 5
	}

### OptionalAlsoProperty1 Getting
	It "OptionalAlsoProperty1 1 Parameter" {
        $result = $obj.OptionalAlsoProperty1(2)
		$result | Should Be 3
	}
	It "OptionalAlsoProperty1 2 Parameters" {
        $result = $obj.OptionalAlsoProperty1(2,3)
		$result | Should Be 5
	}

    It "OptionalAlsoProperty with 3 parameters throws correctly" {
        try {
            $obj.OptionalAlsoProperty1(2,3,4)
            Throw "OK"
        }
        catch {
            $_.Exception.GetType().FullName | Should Be "System.Management.Automation.GetValueInvocationException"
        }
    }

	It "OptionalAlsoProperty1 Parameter is correct after set" {
        $obj.OptionalAlsoProperty1(1)=2
        $result = $obj.OptionalAlsoProperty1(1)
		$result | Should Be 6
	}
	It "OptionalAlsoProperty1 1 Parameter after set" {
        $result = $obj.OptionalAlsoProperty1(1,2)
		$result | Should Be 7
	}

    It "OptionalAlsoProperty1 with no parameters throws correctly" {
        try {
            $obj.OptionalAlsoProperty1()
            Throw "OK"
        }
        catch {
            $_.Exception.GetType().FullName | Should Be "System.Management.Automation.GetValueInvocationException"
        }
    }

}
Describe -tags 'Innerloop', 'DRT' "ParameterizedPropertyGet" {
#    <summary>Parameterized property access</summary>
    BeforeAll {
        $obj = new-object -com  "Scripting.Dictionary"
        $apple = "Apple"
        $obj.Add("A", $apple)
    }
	It "COM  parameterized property access doesn't return same valuea as value set" {
		$obj.Item("A") | Should Be $apple
	}
}
Describe -tags 'Innerloop', 'DRT' "COM ParameterizedProperty" {
#    <summary>Parameterized property access</summary>
    BeforeAll {
        $obj = new-object -com  "Scripting.Dictionary"
        $apple = "Apple"
        $obj.Add("A", $apple)
    }

	It "COM parameterized property IsGettable should return true" {
		$obj.PSObject.Members["Item"].IsGettable | Should Be $true
	}

	It "COM parameterized property IsSettable should return true" {
		$obj.PSObject.Members["Item"].IsSettable | Should Be $true
	}

	It "COM parameterized property typenameofvalue should return proper object type" {
		$obj.PSObject.Members["Item"].TypeNameOfValue | Should Be "System.Object"
	}

	It "COM for Count property IsGettable should return true" {
		$obj.PSObject.Members["Count"].IsGettable | Should Be $true
	}

	It "COM property IsSettable should return false" {
		$obj.PSObject.Members["Count"].IsSettable | Should Be $false
	}
	It "COM property ToString should return proper value" {
        $string = $obj.PSObject.Members["Count"].ToString()
		$string | Should Match "Count"
	}

	It "COM property typeNameofvalue should return int32" {
		$obj.PSObject.Members["Count"].TypeNameOfValue | Should Be "System.Int32"
	}
}

Describe -tags 'Innerloop', 'DRT' "COM ParameterizedPropertySet can be reset" {
#    <summary>Parameterized property access</summary>

    BeforeAll {
        $obj = new-object -com  "Scripting.Dictionary"
        $apple = "Apple"
        $obj.Add("A", $apple)
        $apple = "Orange"
        $obj.Item("A")  = $apple
    }

	It "COM  parameterized property set returns the same value as value set" {
		$obj.Item("A") | Should Be $apple
	}
}

Describe -tags 'Innerloop', 'DRT' "PropertyGet" {
#    <summary>test cases COM interop</summary>

    BeforeAll {
        $obj = new-object -com  "Scripting.FileSystemObject"
        $fldr = $obj.GetFolder("${TestDrive}")
        $path = $fldr.Path
    }

    AfterAll {
        $fldr = $obj = $null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }

	It "COM property access returns the same value as .net property access" {
        $dirinfo = new-object -type System.IO.DirectoryInfo ${TestDrive}
        $root = $dirinfo.FullName
		$path | Should Be $root
	}
}

Describe -tags 'Innerloop', 'DRT' "COM PropertySet" {
#    <summary>test cases COM interop</summary>
    BeforeAll {
        $obj = new-object  -com  "Scripting.FileSystemObject"
        $file = $obj.CreateTextFile("${TestDrive}\comtestfile.txt", $true)
        $file.WriteLine("Test Content")
        $file.Close()
        $file= $obj.GetFile("${TestDrive}\comtestfile.txt")
        $file.Name = "comnewtestfile.txt"
    }
    AfterAll {
        $file = $null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }

	It "COM property set is not successful" {
		$file.Name | Should Be "comnewtestfile.txt"
	}
}
Describe -tags 'Innerloop', 'DRT' "RefArguments" {
#    <summary>test cases COM interop</summary>
    BeforeAll {
        $com=new-object -COM MSHCOMTEST.RefParameters
    }
	It "Com Methods [ref] should be correct" {
        $b="hello1 "
        $com.OutString("world1",[ref]$b)
		$b | Should Be "hello1 world1"
	}

	It "Property Get with [ref] should be correct" {
        $b="hello2 "
        $null = $com.OutStringProperty("world2",[ref]$b)
		$b | Should Be "hello2 world2"
	}

	It "Property Set with [ref] should be correct" {
        $b="hello3 "
        $com.OutStringProperty("world3",[ref]$b) = 3
		$b | Should Be "hello3 world3"
	}

    It "Setting OutStringProperty with [ref] should fail" {
        $b="hello3 "
        try {
            $com.OutStringProperty("world3",[ref]$b) = [ref]$b
            Throw "OK"
        }
        catch {
            $_.Exception.getType() | Should be ([System.Management.Automation.SetValueInvocationException])
        }
    }
}

