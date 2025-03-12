# Delphi 11.3 Json Mapper's between Record

The Delphi Json Mapper Record is a native RTL technique from Delphi 11 Alexandria generating units for the record, which allows dynamic conversion between JSON structures and records.

### 📌 Main Features:

```text

 ✅ Dynamic JSON Mapping: Allows for automatic parsing and generation of records from arbitrary JSONs, without having to manually define each field.

 ✅ Bidirectional Conversion: Provides methods to serialize and deserialize JSONs to records using TJSONMarshal and TJSONUnMarshal.

 ✅ Support for Different JSON Types: Recognizes various types such as jtObject, jtArray, jtString, jtNumber, jtDate, jtDateTime, etc.

 ✅ Delphi Code Generation: Provides methods to generate Delphi source code with mapped records, facilitating integration into projects.

 ✅ Customization by Attributes: Can use [JSONReflect] to control the mapping of specific fields when necessary.

 ✅ Use of RTTI: Dynamic parsing is done through RTTI, allowing access and manipulation of types at runtime.

```


## Inout a JSON exiting Record unit

### Sample of the uses unit generated MyMappedRecordEntity

```pascal

uses
  System.SysUtils, System.Classes, System.JSON, JsonMapperAdapter, MyMappedRecordEntity;

procedure TestJsonMapper;
var
  Mapper: iJsonMapper;
  JsonString: string;
  MappedRecord: TMyMappedRecord;
  I: Integer;
begin
  // Input JSON
  JsonString := 
      ' {                                                             ' +
      '     "address": { "city": "Wonderland", "street": "Main St" }, ' +
      '     "age": 30,                                                ' +
      '     "friends": [                                              ' +
      '         { "age": 25, "name": "Bob"     },                     ' +
      '         { "age": 28, "name": "Charlie" }                      ' +
      '     ],                                                        ' +
      '     "hobbies": [                                              ' +
      '         "Reading",                                            ' +
      '         "Traveling",                                          ' +
      '         "Coding"                                              ' +
      '     ],                                                        ' +
      '     "name": "Alice"                                           ' +
      ' }                                                             ' ;

  // Creates the mapper and generates the record
  Mapper := TJsonMapper.Create;

  if Mapper.JsonString(JsonString)
            .RootRecordName('TMyMappedRecord')
            .UnitName('MyMappedRecordEntity')
            .SaveToFile then
    Writeln('Record generated successfully!');

  // Load JSON into registry
  MappedRecord := TMyMappedRecord.Create(JsonString);

  // Displays mapped record data
  Writeln('Nome: ', MappedRecord.Name);
  Writeln('Idade: ', MappedRecord.Age);
  Writeln('Endereço: ', MappedRecord.Address.Street, ', ', MappedRecord.Address.City);

  Writeln('Hobbies:');
  for I := 0 to High(MappedRecord.Hobbies) do
    Writeln('  - ', MappedRecord.Hobbies[I]);

  Writeln('Amigos:');
  for I := 0 to High(MappedRecord.Friends) do
    Writeln(Format('  - Nome: %s | Idade: %.0f', [MappedRecord.Friends[I].Name, MappedRecord.Friends[I].Age]));

  // Serialize the record back to JSON
  Writeln('JSON Gerado:');
  Writeln(MappedRecord.StringiFy);
end;

```

### Input JSON sample

```json
{
  "name": "Alice",
  "age": 30,
  "hobbies": ["Reading", "Traveling", "Coding"],
  "address": {
    "street": "Main St",
    "city": "Wonderland"
  },
  "friends": [
    { "name": "Bob", "age": 25 },
    { "name": "Charlie", "age": 28 }
  ]
}
```

### Output this UNIT

```pascal
unit MyMappedRecordEntity;

interface

uses Generics.Collections, System.JSON.Serializers;

type
  TFriends = record
    [JsonNameAttribute('name')]
    Name: String;
    [JsonNameAttribute('age')]
    Age: Extended;
  end;

  TAddress = record
    [JsonNameAttribute('street')]
    Street: String;
    [JsonNameAttribute('city')]
    City: String;
  end;

  [JsonSerializeAttribute(TJsonMemberSerialization.Fields)]
  TMyMappedRecord = record
    [JsonNameAttribute('name')]
    Name: String;
    [JsonNameAttribute('age')]
    Age: Extended;
    [JsonNameAttribute('hobbies')]
    Hobbies: TArray<String>;
    [JsonNameAttribute('address')]
    Address: TAddress;
    [JsonNameAttribute('friends')]
    Friends: TArray<TFriends>;

    constructor Create(const aJson: string);
    function StringiFy: string;

    procedure HobbiesSize(const aValue: integer);
    procedure FriendsSize(const aValue: integer);
  end;

implementation

{ TMyMappedRecord }

constructor TMyMappedRecord.Create(const aJson: string);
begin
  with TJsonSerializer.Create do
  try
    Populate<TMyMappedRecord>(aJson, Self);
  finally
    Free;
  end;
end;

function TMyMappedRecord.StringiFy: string;
begin
  with TJsonSerializer.Create do
  try
    Result := Serialize<TMyMappedRecord>(Self);
  finally
    Free;
  end;
end;

procedure TMyMappedRecord.HobbiesSize(const aValue: integer);
begin
  SetLength(Hobbies, aValue);
end;

procedure TMyMappedRecord.FriendsSize(const aValue: integer);
begin
  SetLength(Friends, aValue);
end;

end.
```

### Sample of the test to class Mapper TJsonMapperAdapter

#### program of test use DUnitX

```pascal
program TestJsonMapper;

uses
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.XML.NUnit,
  DUnitX.TestRunner,
  System.SysUtils;

{$APPTYPE CONSOLE}

begin
  ReportMemoryLeaksOnShutdown := True;
  DUnitX.Loggers.Console.TDUnitXConsoleLogger.SetupLogging;
  DUnitX.TestRunner.RunRegisteredTests;
end.
```

#### Unit of the test

```pascal
unit TestMyMappedRecord;

interface

uses
  DUnitX.TestFramework, MyMappedRecordEntity, System.SysUtils;

type
  [TestFixture]
  TTestMyMappedRecord = class
  private
    FJsonString: string;
    FRecord: TMyMappedRecord;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestLoadFromJson;

    [Test]
    procedure TestStringiFy;
  end;

implementation

{ TTestMyMappedRecord }

procedure TTestMyMappedRecord.Setup;
begin
  FJsonString := 
      ' {                                                             ' +
      '     "address": { "city": "Wonderland", "street": "Main St" }, ' +
      '     "age": 30,                                                ' +
      '     "friends": [                                              ' +
      '         { "age": 25, "name": "Bob"     },                     ' +
      '         { "age": 28, "name": "Charlie" }                      ' +
      '     ],                                                        ' +
      '     "hobbies": [                                              ' +
      '         "Reading",                                            ' +
      '         "Traveling",                                          ' +
      '         "Coding"                                              ' +
      '     ],                                                        ' +
      '     "name": "Alice"                                           ' +
      ' }                                                             ' ;
end;

procedure TTestMyMappedRecord.TearDown;
begin
end;

procedure TTestMyMappedRecord.TestLoadFromJson;
begin
  FRecord := TMyMappedRecord.Create(FJsonString);

  Assert.AreEqual('Alice', FRecord.Name);
  Assert.AreEqual(30.0, FRecord.Age, 0.1);
  Assert.AreEqual('Main St', FRecord.Address.Street);
  Assert.AreEqual('Wonderland', FRecord.Address.City);

  Assert.AreEqual(3, Length(FRecord.Hobbies));
  Assert.AreEqual('Reading', FRecord.Hobbies[0]);
  Assert.AreEqual('Traveling', FRecord.Hobbies[1]);
  Assert.AreEqual('Coding', FRecord.Hobbies[2]);

  Assert.AreEqual(2, Length(FRecord.Friends));
  Assert.AreEqual('Bob', FRecord.Friends[0].Name);
  Assert.AreEqual(25.0, FRecord.Friends[0].Age, 0.1);
  Assert.AreEqual('Charlie', FRecord.Friends[1].Name);
  Assert.AreEqual(28.0, FRecord.Friends[1].Age, 0.1);
end;

procedure TTestMyMappedRecord.TestStringiFy;
var
  OutputJson: string;
begin
  FRecord := TMyMappedRecord.Create(FJsonString);
  OutputJson := FRecord.StringiFy;

  Assert.IsTrue(OutputJson.Contains('"name":"Alice"'));
  Assert.IsTrue(OutputJson.Contains('"age":30'));
  Assert.IsTrue(OutputJson.Contains('"street":"Main St"'));
  Assert.IsTrue(OutputJson.Contains('"city":"Wonderland"'));
  Assert.IsTrue(OutputJson.Contains('"name":"Bob"'));
  Assert.IsTrue(OutputJson.Contains('"name":"Charlie"'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestMyMappedRecord);

end.

```



