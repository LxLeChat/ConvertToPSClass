# JsonToPSClass
This is an attempt to convert PSCustomObject to Powershell Class.
I made this because i was tired to to convert json into PS Classes manually, so i could later cast them into a custom type.
The main purpose, for me, is to do something like this `` [MyCustomType]($SomeJson | ConvertFrom-Json)``

# Comment
This is not perfect, and there are many caveats that we will see after some examples. Maybe there are better ways to do this

# Usage
Load the module ``Import-Module .\convertToPSClass.psd1``
Then convert to a PS Class and output as a string

```Powershell
#Basic PSCustomobject
$MyObject = [PSCustomObject]@{
    MyPropertyIsAnInteger=1
    ThisIsAString="oulala"
    AnArrayOfIntegers = 1..10
}

$MyObject | ConvertTo-PSClass -RootClassName "MyCustomObject" -AsString

Class MyCustomObject {
	[Int]$MyPropertyIsAnInteger
	[String]$ThisIsAString
	[Int[]]$AnArrayOfIntegers
 
	## Place your Custom Method(s) below
	## ToString(){} 
}
```

The output can also be an object, if you want to explore it later or add properties
```Powershell
$MyEntry = $MyObject | ConvertTo-PSClass -RootClassName "MyCustomObject"
$MyEntry

Name           Properties                                                                       IsRoot
----           ----------                                                                       ------
MyCustomObject {[Int]$MyPropertyIsAnInteger, [String]$ThisIsAString, [Int[]]$AnArrayOfIntegers}   True

$MyEntry.properties
[Int]$MyPropertyIsAnInteger
[String]$ThisIsAString
[Int[]]$AnArrayOfIntegers

## Add a new property
## [property] -> new -> Name, Type, IsList
$MyEntry.Properties += [Property]::new("MyNewProperty","String",$True)

## Turn into a string
$MyEntry.ToString()

Class MyCustomObject {
        [Int]$MyPropertyIsAnInteger
        [String]$ThisIsAString
        [Int[]]$AnArrayOfIntegers
        [String[]]$MyNewProperty

        ## Place your Custom Method(s) below
        ## ToString(){}
}
```

## Adding Attributes
You can add and attribute to your properties, using the ``BasicAttributes`` enum and the ``AddAttribute`` Method on a property
with the above example
```Powershell
$MyEntry.Properties[0].AddAttributes([BasicAttributes]::AllowNull)

Name                  Type IsList Attribute
----                  ---- ------ ---------
MyPropertyIsAnInteger Int   False [AllowNull()]

## if we convert our property to a string we will get the following
$MyEntry.Properties[0].ToString()

[AllowNull()]
[Int]$MyPropertyIsAnInteger
```

## Hidden properties
An entry contains some hidden properties:
``Child``, if for example one property of your object is a PSCustomObject, or an array of PSCustomobject.
``Parent``, a ``Child`` entry has a parent.. it might come handy sometime in the futur...
``Object`` wich contains the corresponding Object.

## Problems
i encountered a problem where a json contains a list of objects. But each object does not have the same properties.
At the moment i only fetch the first object and create a new entry. 
If we look a the json below :
```Powershell
'{"pattern": [ {"Prop1":1,"Prop2":"aze"}, {"Prop1":1,"Prop2":"aze","Prop3":"I will be Missing.."} ]}' | ConvertFrom-Json | Convertto-PSClass -RootClassName MyCustomObject -AsString

Class pattern {
        [Int]$Prop1
        [String]$Prop2

        ## Place your Custom Method(s) below
        ## ToString(){}
}
Class MyCustomObject {
        [pattern[]]$pattern

        ## Place your Custom Method(s) below
        ## ToString(){}
}
```
``Prop3`` is missing from my pattern class.

When casting this will result in an ``InvalidCastConstructorException``:
```powershell
[MyCustomObject]('{"pattern": [ {"Prop1":1,"Prop2":"aze"}, {"Prop1":1,"Prop2":"aze","Prop3":"Im Missing.."} ]}' | ConvertFrom-Json)
```
You can do the following to find the class (sorry in french, but it says: Prop3 is missing from object Pattern)
```powershell
$error[0].Exception.getBaseException()
La propri??t?? Prop3 est introuvable pour l???objet pattern. La propri??t?? disponible est la suivante : [Prop1 <System.Int32>] , [Prop2 <System.String>]
```

## Duplicate classes
When ``-AsString`` is used, the ``ToString()`` method will remove any duplicate classes. To do so, we create a scriptblock, and if any errors are raised it's likely due to duplicate classes. We then explore the error, get problematic extent, and remove them. This is not very accurate but it's the best i managed :)

## Notes about importing the module
In order to have the classes & enums avaible in the console when importing the module, classes & enums are in seperate ps1 file, wich are then referenced in the ``ScriptToProcess`` in the psd1 file.
