
using namespace system.Collections.Generic;

function ConvertTo-PSClass {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [PSobject]$InputObject,
        [String]$RootClassName = "Root",
        [switch]$AsString
    )
    
    begin {
        
    }
    
    process {
        If ( $AsString ) {
            return ([entry]::new($InputObject,$RootClassName,$True)).ToString()
        }
        [entry]::new($InputObject,$RootClassName,$True)
    }
    
    end {
        
    }
}


Class Duplicate {
    [String]$Name
    [String[]]$Properties
    [Int]$PropertiesCount
    [String]$AsString
}

Enum BasicAttributes {
    AllowNull = 1
    AllowEmptyString = 2
    AllowEmptyCollection = 3
    ValidateNotNull = 4
    ValidateNotNullOrEmpty = 5
    ValidateCount = 6
    ValidateLength = 7
    ValidateRange = 8
    ValidateSet = 9
    ValidatePattern = 10
}

Class Property {
    [String]$Name
    [String]$Type
    [Bool]$IsList
    [String]$Attribute

    Property ([String]$Name,[String]$Type,[Bool]$IsList) {
        $this.Name = $Name
        $this.Type = $Type
        $this.IsList = $IsList
    }

    [String] ToString () {
        $attr = $null
        if ( -not [string]::IsNullOrEmpty($this.Attribute) ) {
            $attr = '{0}{1}' -f $this.Attribute.ToString(), "`r`n"
        }

        if ( $this.IsList ) {
            return '{2}[{0}[]]${1}' -f $this.Type, $this.Name, $attr
        }

        return '{2}[{0}]${1}' -f $this.Type, $this.Name, $attr
    }

    [Void] AddAttribute ([BasicAttributes]$Attribute) {
        ## must be an attribute in 1..5
        if ( -not ($Attribute -in 1..5) ) {
            throw "Attribute must be in 1..5"
        }
        $this.Attribute = '[{0}()]' -f $Attribute.ToString()
    }

    ## for ValidateCount,ValidateLength,ValidateRange
    [Void] AddAttribute ([BasicAttributes]$Attribute,[int]$Start,[Int]$End) {
        ## must be an attribute in 6..8
        if ( -not ($Attribute -in 6..8) ) {
            throw "Attribute must be in 6..8"
        }
        $this.Attribute = '[{0}({1}..{2})]' -f $Attribute.ToString(), $start, $end
    }

    ## for ValidateSet
    [Void] AddAttribute ([BasicAttributes]$Attribute,[Array]$Set) {
        ## must be an attribute in 9
        if ( -not ($Attribute -eq 9) ) {
            throw "Attribute must be 9"
        }
        $this.Attribute = '[{0}("{1}")]' -f $Attribute.ToString(), $($set -join '","')
    }

    ## for ValidatePattern
    [Void] AddAttribute ([BasicAttributes]$Attribute,[String]$Pattern) {
        ## must be an attribute in 10
        if ( -not ($Attribute -eq 10) ) {
            throw "Attribute must be 10"
        }
        $this.Attribute = '[{0}("{1}")]' -f $Attribute.ToString(), $Pattern
    }

}

Class Entry {
    [String]$Name
    [Property[]]$Properties
    [Boolean]$IsRoot
    hidden [Entry]$Parent
    hidden [Entry[]]$Child
    hidden [object]$Object

    ## default constructor
    Entry ([Object]$Object,[String]$Name,[Boolean]$IsRoot) {
        $this.Object = $Object
        $this.Name = $Name

        ##pas forcement utile mais bon ...
        If ( $IsRoot ) {
             $this.IsRoot = $True
        }

        $this.ParseProperties()
    }

    ## constructor used when a child object is added
    Entry ([Entry]$Parent,[Object]$Object,[String]$Name,[Boolean]$IsRoot) {
        $this.Object = $Object
        $this.Name = $Name
        $this.parent = $parent

        ##pas forcement utile mais bon ...
        If ( $IsRoot ) {
             $this.IsRoot = $True
        }

        $this.ParseProperties()
    }

    [void] ParseProperties () {
        foreach($Prop in $this.Object.PSObject.properties) {
            If ( $Prop.TypeNameOfValue -match '^System.String')
            {
                $This.SetStringProperty($Prop)
                Continue
            }

            If ( $Prop.TypeNameOfValue -match '^System.Int')
            {
                $This.SetIntegerProperty($Prop)
                Continue
            }

            If ( $Prop.TypeNameOfValue -match '^System.Boolean')
            {
                $This.SetBooleanProperty($Prop)
                Continue
            }

            If ( $Prop.TypeNameOfValue -match '^System.Management.Automation.PSCustomObject')
            {
                $This.SetPSCustomObjectProperty($Prop)
                Continue
            }

            If ( $Prop.TypeNameOfValue -match '^System.Object\[\]')
            {
                $This.SetArrayObjectProperty($Prop)
                Continue
            }
        }
    }

    ## called when property is a String
    [void] SetStringProperty ([PSNoteProperty]$NoteProperty) {
        $this.Properties += [Property]::new($NoteProperty.Name,"String",$false)
    }

    ## called when property is an array of Strings
    [void] SetArrayStringProperty ([PSNoteProperty]$NoteProperty) {
        $this.Properties += [Property]::new($NoteProperty.Name,"String",$True)
    }

    ## called when property is a Interger
    [void] SetIntegerProperty ([PSNoteProperty]$NoteProperty) {
        $this.Properties += [Property]::new($NoteProperty.Name,"Int",$False)
    }

    ## called when property is an array of Intergers
    [void] SetArrayIntegerProperty ([PSNoteProperty]$NoteProperty) {
        $this.Properties += [Property]::new($NoteProperty.Name,"Int",$True)
    }
    
    ## called when property is a Boolean
    [void] SetBooleanProperty ([PSNoteProperty]$NoteProperty) {
        $this.Properties += [Property]::new($NoteProperty.Name,"Bool",$False)
    }

    ## called when property is a PSCustomObject
    [void] SetPSCustomObjectProperty ([PSNoteProperty]$NoteProperty) {
        # $this.Properties += $('[{0}]${0}' -f $NoteProperty.Name)
        $this.Properties += [Property]::new($NoteProperty.Name,$NoteProperty.Name,$False)
        $this.AddChild($this.Object."$($NoteProperty.Name)",$NoteProperty.Name)
        
    }

    ## called when property is a PSCustomObject
    [void] SetArrayNullObjectProperty ([PSNoteProperty]$NoteProperty) {
        $this.Properties += [Property]::new($NoteProperty.Name,'Object',$True)
    }
    
    ## called when property is a PSCustomObject
    [void] SetArrayPSCustomObjectProperty ([PSNoteProperty]$NoteProperty) {
        $this.Properties += [Property]::new($NoteProperty.Name,$NoteProperty.Name,$True)
        ## enfait ici, si certains objets ont pas tous les mêmes propriétés
        ## il manquera des propriété lors du cast et ça causera des erreurs
        ## est ce que on pourrait pas tous les créer, comparé les propriétés ?
        ## ou pas faire de add child, mais juste des entry et comparé les propriété ?
        ## sur le child 1 on a x propriétés, sur le child 2 on a une propriété en plus, on garde le child 2
        ## { 
        #   "MonTableauObjet" : [
        #       {"prop1":1,"prop2":2},
        #       {"prop1":1,"prop2":2,"prop3":3}
        #   ]
        ## }
        ## on pourrait tet le faire dans la méthode ParseProperties,
        ## ou dans addchild, on crée l'entrée, et on check le parent:
        ## $entry.parent.object."$entry.Name" | %{ $_.psobject.properties } | select name -unqiue

        ## Sometimes, in a list of objects, objects dont have the same propertie...
        ## object1 can have 2 properties, object2 3 properties .. ( see example above)
        ## this is pretty annoying .. at the moment we only base the new child on the first object of the list.
        ## when you'll cast as the generated classes, you'll get errors saying: this onlyc accepts this properties .. wich are : ...
        ## $error[0].Exception.GetBaseException() will get you the problematic class.. and you will have to manually add the property
        $this.AddChild($this.Object."$($NoteProperty.Name)"[0],$NoteProperty.Name)
    }

    ## Calls SetArrayType Methods
    [void] SetArrayObjectProperty ([PSNoteProperty]$NoteProperty) {
        $UniqueType = $this.Object."$($NoteProperty.Name)" | ForEach-Object {$_.Psobject.TypeNames[0]} | Select-Object -Unique
        if ( $null -eq $UniqueType) {
            $this.SetArrayNullObjectProperty($NoteProperty)
            return
        }

        if ( $UniqueType -Match '^System.String') {
            $This.SetArrayStringProperty($NoteProperty)
            return
        }

        If ( $UniqueType -Match '^System.Int') {
            $This.SetArrayIntegerProperty($NoteProperty)
            return
        }

        If ( $UniqueType -Match '^System.Management.Automation.PSCustomObject') {
            $This.SetArrayPSCustomObjectProperty($NoteProperty)
            return
        }

        Throw "SetArrayObjectProperty, Type: $UniqueType not implemented..."
    }

    ## called if we have a PSCustomObject
    AddChild([Object]$Object,[String]$Name){
        $entry = [Entry]::new($this,$Object,$Name,$false)
        $this.Child += $entry
    }

    [bool] HasChild () {
        return $(-not $null -eq $this.Child)
    }

    [string] ToString () {
        $Plop = "`n`t## Place your Custom Method(s) below`n`t## ToString(){}"

        $classPropertiesAsString = @()
        foreach ($prop in $this.properties){
            $classPropertiesAsString += $prop.ToString()
        }

        $base = 'Class {0} {1} {2} {3}' -f $this.Name,("{`n`t" + $($classPropertiesAsString -join "`n`t") + "`n"), $plop, "`n}"
        
        if ( $this.HasChild() ) {
            $zou = @()
            foreach ( $child in $this.child) {
                $zou += $Child.ToString()
            }

            ## executed at the end, when all child and subchild where parsed
            if ( $this.IsRoot) {

                $zap = $($($zou -join "`n`n") + "`n" +$base)
                try {
                    ## si on a des classes en double le Scriptblock
                    ## va throw, et on peut recup les extent a delete
                    ## if we have duplicate classes, the create method will throw
                    ## allowing us to explore the error object to find the classes
                    $null = [scriptblock]::create($zap)
                    return $zap
                } catch {
                    ## on créer un tableau qui contiendra
                    ## les offset de debut ainsi que la longueur qu'on souhaite delete
                    ## toremove is an array containing start offset and length of the extent in order to delete the string
                    $toremove = @($_.exception.GetBaseException().Errors.extent | Select-Object StartOffset,@{l='StringLength';e={$_.text.length+1}})
                    ## on commence par la fin... c'est mieux
                    ## we start from the end
                    $toremove[$toremove.Length..0] | ForEach-Object { $zap = $zap.remove($_.startoffset,$_.stringLength)}
                    return $zap
                }
            }

            return $($($zou -join "`n`n") + "`n" +$base)
        }

        return $base
    }


    ## !!! this is not used at the moment !!!
    ## used for TraverseForDuplicates method
    hidden [string] ToPSClass () {
        $Plop = "`n`t## Place your Custom Method(s) below`n`t## ToString(){}"
        $classPropertiesAsString = @()
        foreach ($prop in $this.properties){
            $classPropertiesAsString += $prop.ToString()
        }  
        
        $base = 'Class {0} {1} {2} {3}' -f $this.Name,("{`n`t" + $($classPropertiesAsString -join "`n`t") + "`n"), $plop, "`n}"

        return $base
    }

    ## !!! this is not used at the moment !!!
    ## !!! its the beginning of an idea   !!!
    ## This is not called directly but this is the real logic to find duplicates..
    hidden [Dictionary[[string],[List[Duplicate]]]] TraverseForDuplicates ([Dictionary[[string],[List[Duplicate]]]]$Duplicates) {

        if ( $this.HasChild() ) {
            foreach ( $child in $this.Child) {

                $tmp = [Duplicate]@{
                    Name = $child.Name
                    Properties = $Child.Properties
                    PropertiesCount = $Child.Properties.count
                    AsString = $Child.ToPSClass()
                }

                if ( -not $Duplicates.ContainsKey($Child.name) ) {
                    $Duplicates.add($child.Name, $tmp)
                } else {
                    $Duplicates[$child.Name].add($tmp)
                }
                $child.TraverseForDuplicates($Duplicates)
            }
        }

        return $Duplicates
    }

    ## !!! this is not used at the moment !!!
    ## this is called to find duplicates, at the moment it will display a string
    ## listing all duplicates, and how many times this class is present
    hidden [Array] FindDuplicates () {
        if ( -not $this.IsRoot) { throw "Not implemented"}

        ## contains all entries. Key is the name of the class, and the value is a list of actuals object
        ## so if you do : $Duplicates['MySubClass'].count this will give us the 
        $Duplicates = $this.TraverseForDuplicates([Dictionary[[string],[List[Duplicate]]]]@{})

        If ( $Duplicates.count -eq 0 ) {
            return $null
        }

        return $Duplicates.GetEnumerator().where({$_.Value.Count -gt 1})

    }
}
