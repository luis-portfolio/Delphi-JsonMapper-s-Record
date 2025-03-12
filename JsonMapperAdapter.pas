unit JsonMapperAdapter;

interface

uses
   RTTI,
   System.JSON, System.RegularExpressions, System.TypInfo, System.SysUtils, System.Classes, System.Generics.Collections, System.Generics.Defaults,
   Rest.JSON,

   StringHelper;

type

   EJsonMapper = class( Exception );

   TJsonType = ( jtUnknown, jtObject, jtArray, jtString, jtTrue, jtFalse, jtNumber, jtDate, jtDateTime, jtBytes );

   TStubRecord = class;

   iJsonMapper = interface
      [ '{B002B9DE-F726-4E0D-9CDC-BDA8A9FE6E18}' ]
      procedure Debug( aLines: TStrings );

      function JsonString: string; overload;
      function JsonString( aValue: string ): iJsonMapper; overload;

      function RootRecordName: string; overload;
      function RootRecordName( const aValue: string ): iJsonMapper; overload;

      function UnitFullName: string;
      function UnitName: string; overload;
      function UnitName( const aValue: string ): iJsonMapper; overload;

      function UnitPreview: string;
      function SaveToFile: boolean;
   end;

   TJsonMapper = class( TInterfacedObject, iJsonMapper )
      constructor Create;
      destructor Destroy; override;
   private
      FRecords       : TList<TStubRecord>;
      FRootRecord    : TStubRecord;
      FUnitName      : string;
      FUnitFullName  : string;
      FJsonString    : string;
      FRootRecordName: string;
   strict protected
      function Parse( aJsonString, aRootRecordName: string ): boolean;
      function GenerateUnit: string;

   protected
      function GetJsonType( aJsonValue: TJsonValue ): TJsonType;
      function GetFirstArrayItem( aJsonValue: TJsonValue ): TJsonValue;
      procedure ClearRecords;
      procedure ProcessJsonObject( aJsonValue: TJsonValue; aParentRecord: TStubRecord );
      function SuggestRecordName( aSuggestedRecordName: string ): string;
   public

      procedure Debug( aLines: TStrings );

      function JsonString: string; overload;
      function JsonString( aValue: string ): iJsonMapper; overload;

      function RootRecordName: string; overload;
      function RootRecordName( const aValue: string ): iJsonMapper; overload;

      function UnitFullName: string;
      function UnitName: string; overload;
      function UnitName( const aValue: string ): iJsonMapper; overload;

      function UnitPreview: string;
      function SaveToFile: boolean;
   end;

   TStubField = class
      class function GetTypeAsString( aType: TJsonType ): string; overload;
      constructor Create( aParentRecord: TStubRecord; aItemName: string; aFieldType: TJsonType );
      destructor Destroy; override;
   private
      FAlias       : string;
      FName        : string;
      FFieldName   : string;
      FFieldType   : TJsonType;
      FParentRecord: TStubRecord;
      procedure SetName( const aValue: string );
   public
      function GetTypeAsString: string; overload; virtual;

      property Name: string read FName write SetName;
      property FieldName: string read FFieldName write FFieldName;
      property FieldType: TJsonType read FFieldType write FFieldType;
   end;

   TStubContainerField = class( TStubField )
   private
      FFieldRecord  : TStubRecord;
      FContainedType: TJsonType;
   public
      property ContainedType: TJsonType read FContainedType write FContainedType;
      property FieldRecord  : TStubRecord read FFieldRecord write FFieldRecord;
   end;

   TStubObjectField = class( TStubContainerField )
   private
   public
      constructor Create( aParentRecord: TStubRecord; aItemName: string; aItemRecord: TStubRecord );
      function GetTypeAsString: string; override;
   end;

   TStubArrayField = class( TStubContainerField )
   private
   public
      constructor Create( aRecord: TStubRecord; aItemName: string; aItemSubType: TJsonType; aItemRecord: TStubRecord );
      function GetTypeAsString: string; override;
   end;

   TStubRecord = class
   private
      FItems         : TList<TStubField>;
      FComplexItems  : TList<TStubField>;
      FArrayItems    : TList<TStubField>;
      FName          : string;
      FAlias         : string;
      FParentRecord  : TStubRecord;
      FMapper        : TJsonMapper;
      FPureRecordName: string;
      FArrayProperty : string;
      procedure SetName( const aValue: string );
      procedure SetPureRecordName( const aValue: string );
   public
      constructor Create( aParentRecord: TStubRecord; aRecordName: string; aMapper: TJsonMapper; aArrayProperty: string = '' );
      destructor Destroy; override;

      function GetDeclarationPart: string;
      function GetImplementationPart: string;

      property Name: string read FName write SetName;
      property Items: TList<TStubField> read FItems write FItems;
      property PureRecordName: string read FPureRecordName write SetPureRecordName;
      property ArrayProperty: string read FArrayProperty write FArrayProperty;

   end;

var
   PointDsFormatSettings: TFormatSettings;

function Mapper: iJsonMapper;

implementation

var
   ReservedWords: TList<string>;

const
   COLON       = ':';
   SEMICOLON   = ';';
   INDENT_SIZE = 2;

function Mapper: iJsonMapper;
begin
   Result := TJsonMapper.Create;
end;

{ TJsonMapper }

constructor TJsonMapper.Create;
begin
   inherited Create;
   FRecords        := TList<TStubRecord>.Create;
   FUnitName       := EmptyStr;
   FUnitFullName   := EmptyStr;
   FRootRecordName := EmptyStr;
end;

destructor TJsonMapper.Destroy;
begin
   ClearRecords;
   FreeAndNil( FRecords );
   inherited;
end;

function TJsonMapper.GetJsonType( aJsonValue: TJsonValue ): TJsonType;
var
   LJsonString: TJSONString;
begin
   if aJsonValue is TJSONObject then
      Result := jtObject
   else
      if aJsonValue is TJSONArray then
      Result := jtArray
   else
      if ( aJsonValue is TJSONNumber ) then
      Result := jtNumber
   else
      if aJsonValue is TJSONTrue then
      Result := jtTrue
   else
      if aJsonValue is TJSONFalse then
      Result := jtFalse
   else
      if aJsonValue is TJSONString then
   begin
      LJsonString := ( aJsonValue as TJSONString );
      if TRegEx.IsMatch( LJsonString.Value, '^([0-9]{4})-?(1[0-2]|0[1-9])-?(3[01]|0[1-9]|[12][0-9])(T| )(2[0-3]|[01][0-9]):?([0-5][0-9]):?([0-5][0-9])$' ) then
         Result := jtDateTime
      else
         if TRegEx.IsMatch( LJsonString.Value, '^([0-9]{4})(-?)(1[0-2]|0[1-9])\2(3[01]|0[1-9]|[12][0-9])$' ) then
         Result := jtDate
      else
         Result := jtString
   end
   else
      Result := jtUnknown;
end;

function TJsonMapper.GetFirstArrayItem( aJsonValue: TJsonValue ): TJsonValue;

var
   LJsonArray: TJSONArray;
   LJsonValue: TJsonValue;
begin
   Result     := nil;
   LJsonArray := aJsonValue as TJSONArray;
   for LJsonValue in LJsonArray do
   begin
      Result := LJsonValue;
      break;
   end;
end;

procedure TJsonMapper.ClearRecords;

var
   LRecord: TStubRecord;
begin
   for LRecord in FRecords do
   begin
      LRecord.Free;
   end;

   FRecords.Clear;
end;

procedure TJsonMapper.ProcessJsonObject( aJsonValue: TJsonValue; aParentRecord: TStubRecord );

var
   LJsonObj  : TJSONObject;
   LJsonPair : TJSONPair;
   LJsonVal  : TJsonValue;
   LJsonVal2 : TJsonValue;
   LJsonType : TJsonType;
   LJsonType2: TJsonType;
   LRecord   : TStubRecord;
begin
   LJsonObj := aJsonValue as TJSONObject;

   for LJsonPair in LJsonObj do
   begin
      LJsonVal  := LJsonPair.JSONValue;
      LJsonType := GetJsonType( LJsonVal );

      case LJsonType of
         jtObject:
            begin
               LRecord := TStubRecord.Create( aParentRecord, LJsonPair.JsonString.Value, self );
               TStubObjectField.Create( aParentRecord, LJsonPair.JsonString.Value, LRecord );
               ProcessJsonObject( LJsonVal, LRecord );
            end;

         jtArray:
            begin
               LRecord    := nil;
               LJsonType2 := jtUnknown;

               LJsonVal2 := GetFirstArrayItem( LJsonVal );
               if LJsonVal2 <> nil then
               begin
                  LJsonType2 := GetJsonType( LJsonVal2 );
                  case LJsonType2 of
                     jtObject:
                        begin
                           LRecord := TStubRecord.Create( aParentRecord, LJsonPair.JsonString.Value, self );
                           ProcessJsonObject( LJsonVal2, LRecord );
                        end;
                     jtArray:
                        raise EJsonMapper.Create( 'Nested Arrays are not supported!' );
                  end;
               end;
               TStubArrayField.Create( aParentRecord, LJsonPair.JsonString.Value, LJsonType2, LRecord );
            end;
         jtNumber,
            jtString,
            jtDate,
            jtDateTime,
            jtTrue,
            jtFalse:
            TStubField.Create( aParentRecord, LJsonPair.JsonString.Value, LJsonType );
      end;
   end;
end;

function TJsonMapper.SuggestRecordName( aSuggestedRecordName: string ): string;
var
   LRecord   : TStubRecord;
   LMax, LVal: integer;
   LString   : string;
begin
   Result := aSuggestedRecordName;
   LMax   := 0;

   for LRecord in FRecords do
   begin
      if SameText( LRecord.Name, Result ) then
      begin
         LString := Copy( LRecord.Name, length( Result ) + 2 );
         if ( LString.length = 3 ) then
         begin
            if TryStrToInt( LString, LVal ) then
            begin
               inc( LVal );
               if LVal > LMax then
                  LMax := LVal;
            end;
         end
         else
            LMax := 1;
      end;
   end;

   if LMax > 0 then
      Result := format( '%s_%0.3d', [ Result, LMax ] );
end;

{ TJsonMapper - Public }

function TJsonMapper.Parse( aJsonString, aRootRecordName: string ): boolean;
var
   LJsonValue : TJsonValue;
   LJsonValue2: TJsonValue;
   LJsonType  : TJsonType;
   LRecord    : TStubRecord;
begin
   ClearRecords;
   LJsonValue := TJSONObject.ParseJSONValue( aJsonString );
   if LJsonValue <> nil then
      try
         FRootRecord := TStubRecord.Create( nil, aRootRecordName, self );

         case GetJsonType( LJsonValue ) of
            jtObject:
               begin
                  ProcessJsonObject( LJsonValue, FRootRecord );
               end;

            jtArray:
               begin
                  LJsonType := jtUnknown;
                  LRecord   := nil;

                  LJsonValue2 := GetFirstArrayItem( LJsonValue );
                  if LJsonValue2 <> nil then
                  begin
                     LJsonType := GetJsonType( LJsonValue2 );
                     LRecord   := TStubRecord.Create( FRootRecord, 'Item', self );
                  end;

                  FRootRecord.ArrayProperty := 'Items';
                  TStubArrayField.Create( FRootRecord, 'Items', LJsonType, LRecord );
                  ProcessJsonObject( LJsonValue2, LRecord );
               end;
         end;
         Exit( True );
      finally
         LJsonValue.Free;
      end;

   Result := False;
end;

function TJsonMapper.GenerateUnit: string;
const
   ROOT_RECORD_INDEX = 0;
var
   LIndex: integer;
begin
   if not Parse( self.JsonString, self.RootRecordName ) then
      Exit( 'Json don`t supported!' );

   with TStringBuilder.Create do
      try
         Append( 'unit ' ).Append( self.UnitName ).AppendLine( SEMICOLON ).AppendLine;

         AppendLine( '{' );
         AppendLine( ' ******************************************************************************* ' );
         AppendLine( ' *  Generated By: EntityFromJson - 1.00                                        * ' );
         AppendLine( ' *  Project link: https://github.com/Luis-Portifolio/Delphi-JsonMapper         * ' );
         AppendLine( ' *  Generated On: 2025-01-31 10:48:52                                          * ' );
         AppendLine( ' ******************************************************************************* ' );
         AppendLine( ' *  Created By  : Luis Caldas - 2025                                           * ' );
         AppendLine( ' *  WebSite     : http://app.qbits.pl/LuisCaldas                               * ' );
         AppendLine( ' ******************************************************************************* ' );
         AppendLine( '}' ).AppendLine;

         AppendLine( 'interface' ).AppendLine;
         AppendLine( 'uses Generics.Collections, System.JSON.Serializers;' ).AppendLine;
         AppendLine( 'type' );

         for LIndex := FRecords.Count - 1 downto 0 do
            AppendLine( FRecords[ LIndex ].GetDeclarationPart.TrimRight );

         AppendLine
            .Append( 'implementation' ).AppendLine;

         for LIndex := 0 to FRecords.Count - 1 do
            Append( FRecords[ LIndex ].GetImplementationPart.TrimRight );

         AppendLine;
         AppendLine;
         AppendLine( 'end.' );
         Result := toString; // .MacroApply( 'RootRecordName', RootRecordName );
      finally
         Free;
      end;
end;

procedure TJsonMapper.Debug( aLines: TStrings );
var
   LRecord: TStubRecord;
   LField : TStubField;
begin
   aLines.Clear;

   for LRecord in FRecords do
   begin
      aLines.add( '-------' );
      aLines.add( LRecord.Name );
      for LField in LRecord.FItems do
      begin
         aLines.add( format( '%-15s | %s', [ LField.FieldName, LField.GetTypeAsString ] ) );
      end;
   end;
end;

function TJsonMapper.JsonString: string;
begin
   Result := FJsonString;
end;

function TJsonMapper.JsonString( aValue: string ): iJsonMapper;
begin
   Result      := self;
   FJsonString := aValue;
end;

function TJsonMapper.RootRecordName: string;
var
   LRootRecordName: string;
begin
   LRootRecordName := FRootRecordName.SnakeToPascalCase;

   if not SameStr( FRootRecordName, EmptyStr ) then
      Exit( FRootRecordName );

   LRootRecordName := 'MyMappedRecord';
   Result          := LRootRecordName;
end;

function TJsonMapper.RootRecordName( const aValue: string ): iJsonMapper;
begin
   Result          := self;
   FRootRecordName := aValue.SnakeToPascalCase;
end;

function TJsonMapper.UnitFullName: string;
var
   LFilename: string;
   LPathname: string;
begin
   LFilename := ExtractFileName( FUnitFullName ).SnakeToPascalCase;
   LPathname := ExtractFilePath( FUnitFullName );

   if SameStr( LPathname, EmptyStr ) then
      LPathname := ExtractFilePath( ParamStr( 0 ) );

   if SameStr( LFilename, EmptyStr ) then
      LFilename := RootRecordName + 'Entity.pas';

   if not LFilename.Contains( 'Entity.pas' ) then
      LFilename := LFilename + 'Entity.pas';

   Result := LPathname + LFilename;
end;

function TJsonMapper.UnitName: string;
var
   LFilename: string;
begin
   LFilename := ExtractFileName( FUnitFullName ).SnakeToPascalCase;

   if SameStr( LFilename, EmptyStr ) then
      LFilename := RootRecordName + 'Entity';

   if not LFilename.Contains( 'Entity' ) then
      LFilename := LFilename + 'Entity';

   Result := ChangeFileExt( ExtractFileName( LFilename ), EmptyStr );
end;

function TJsonMapper.UnitName( const aValue: string ): iJsonMapper;
begin
   Result        := self;
   FUnitFullName := aValue;
   FUnitName     := ChangeFileExt( ExtractFileName( aValue ), EmptyStr );
end;

function TJsonMapper.UnitPreview: string;
begin
   Result := GenerateUnit;
end;

function TJsonMapper.SaveToFile: boolean;
var
   LBytes: TBytes;
begin
   try
      with TFileStream.Create( UnitFullName, fmCreate ) do
         try
            LBytes := TEncoding.UTF8.GetBytes( GenerateUnit );
            Write( LBytes, 0, length( LBytes ) );
            Result := True;
         finally
            Free;
         end;
   except
      on E: Exception do
         Result := False;
   end;
end;

{ TStubRecord }

{ TStubRecord - private }

procedure TStubRecord.SetName( const aValue: string );

var
   LName: string;
begin
   FAlias          := aValue;
   LName           := aValue.SnakeToPascalCase;
   FPureRecordName := LName;
   LName           := 'T' + FPureRecordName;
   FName           := FMapper.SuggestRecordName( LName );
end;

procedure TStubRecord.SetPureRecordName( const aValue: string );
begin
   FPureRecordName := aValue;
end;

{ TStubRecord - public }

constructor TStubRecord.Create( aParentRecord: TStubRecord; aRecordName: string; aMapper: TJsonMapper; aArrayProperty: string );
begin
   inherited Create;
   FMapper := aMapper;
   Name    := aRecordName;

   FItems        := TList<TStubField>.Create;
   FComplexItems := TList<TStubField>.Create;
   FArrayItems   := TList<TStubField>.Create;
   FMapper.FRecords.add( self );
   FArrayProperty := aArrayProperty;

   FParentRecord := aParentRecord;
end;

destructor TStubRecord.Destroy;
var
   LItem: TStubField;
begin
   for LItem in FItems.ToArray do
      LItem.Free;

   FreeAndNil( FComplexItems );
   FreeAndNil( FItems );
   FreeAndNil( FArrayItems );
   inherited;
end;

function TStubRecord.GetDeclarationPart: string;
var
   LField    : TStubField;
   LFieldName: string;
   LOne      : boolean;
begin
   LOne := False;
   with TStringBuilder.Create do
      try
         if not Assigned( FParentRecord ) then
            AppendLine.Append( '  [ JsonSerializeAttribute( TJsonMemberSerialization.Fields ) ]' ).AppendLine
         else
            AppendLine;

         Append( '  ' ).Append( FName ).Append( ' = record' ).AppendLine;

         for LField in FItems do
         begin
            if not SameStr( LField.FAlias, LField.FieldName ) then
               Append( '    [JsonNameAttribute(' ).Append( LField.FAlias.QuotedString ).Append( ')]' ).AppendLine;

            Append( '    ' ).Append( LField.FieldName ).Append( COLON ).Append( LField.GetTypeAsString ).AppendLine( SEMICOLON );
         end;

         if not Assigned( FParentRecord ) then
         begin
            AppendLine;
            AppendLine( '    constructor Create(const aJson:string);' );
            AppendLine( '    function StringiFy: string;' );
         end;

         for LField in FItems do
            if LField.FFieldType = jtArray then
            begin
               if not LOne then
                  AppendLine;

               LFieldName := LField.FAlias.SnakeToPascalCase;
               Append( '    procedure ' ).Append( LFieldName ).Append( 'Size( const aValue: integer );' ).AppendLine;

               LOne := True;
            end;

         AppendLine( '  end;' ).AppendLine;

         Result := toString;
      finally
         Free;
      end;
end;

function TStubRecord.GetImplementationPart: string;
const
   RECORD_NAME = 'RecordName';
var
   LField     : TStubField;
   LRecordName: string;
   LFieldName : string;
   LOne       : boolean;
begin
   LOne := False;
   // if Assigned( FParentRecord ) then
   // Exit( EmptyStr );

   LRecordName := FName;

   with TStringBuilder.Create do
      try
         if not Assigned( FParentRecord ) then
            AppendLine
               .Append( ' { ' ).Append( LRecordName ).Append( ' }                                    ' ).AppendLine
               .AppendLine
               .Append( 'constructor ' ).Append( LRecordName ).Append( '.Create(const aJson:string); ' ).AppendLine
               .Append( 'begin                                                                       ' ).AppendLine
               .Append( '  inherited;                                                                ' ).AppendLine
               .Append( '  with TJsonSerializer.Create do                                            ' ).AppendLine
               .Append( '  try                                                                       ' ).AppendLine
               .Append( '    Populate<' ).Append( LRecordName ).Append( '>( aJson, Self );           ' ).AppendLine
               .Append( '  finally                                                                   ' ).AppendLine
               .Append( '    Free;                                                                   ' ).AppendLine
               .Append( '  end;                                                                      ' ).AppendLine
               .Append( 'end;                                                                        ' ).AppendLine
               .AppendLine
               .Append( 'function ' ).Append( LRecordName ).Append( '.StringiFy:string;              ' ).AppendLine
               .Append( 'begin                                                                       ' ).AppendLine
               .Append( '  with TJsonSerializer.Create do                                            ' ).AppendLine
               .Append( '  try                                                                       ' ).AppendLine
               .Append( '    Result := Serialize<' ).Append( LRecordName ).Append( '>( Self );       ' ).AppendLine
               .Append( '  finally                                                                   ' ).AppendLine
               .Append( '    Free;                                                                   ' ).AppendLine
               .Append( '  end;                                                                      ' ).AppendLine
               .Append( 'end;                                                                        ' );

         for LField in self.FItems do
            if LField.FieldType = jtArray then
            begin
               LFieldName := LField.FAlias.SnakeToPascalCase;
               AppendLine;

               if not LOne then
                  AppendLine;

               Append( 'procedure ' ).Append( LRecordName ).Append( '.' ).Append( LFieldName ).Append( 'Size( const aValue: integer );' ).AppendLine
                  .Append( 'begin ' ).AppendLine
                  .Append( '  SetLength( ' ).Append( LField.FieldName ).Append( ', aValue );' ).AppendLine
                  .Append( 'end;' ).AppendLine;

               LOne := True;
            end;

         Result := toString;
      finally
         Free;
      end;
end;

{ TStubArrayField }

constructor TStubArrayField.Create( aRecord: TStubRecord; aItemName: string; aItemSubType: TJsonType; aItemRecord: TStubRecord );
begin
   inherited Create( aRecord, aItemName, jtArray );
   FContainedType := aItemSubType;
   FFieldRecord   := aItemRecord;
   if FContainedType = TJsonType.jtObject then
      aRecord.FArrayItems.add( self );
end;

function TStubArrayField.GetTypeAsString: string;
var
   LSubType: string;
begin
   case FContainedType of
      jtObject:
         LSubType := FFieldRecord.Name;
      jtArray:
         raise EJsonMapper.Create( 'Nested arrays are not supported!' );
   else
      LSubType := GetTypeAsString( FContainedType );
   end;
   Result := format( 'TArray<%s>', [ LSubType ] );
end;

{ TStubObjectField }

constructor TStubObjectField.Create( aParentRecord: TStubRecord; aItemName: string; aItemRecord: TStubRecord );
begin
   inherited Create( aParentRecord, aItemName, jtObject );
   FFieldRecord := aItemRecord;
   aParentRecord.FComplexItems.add( self );
   FContainedType := jtObject;
end;

function TStubObjectField.GetTypeAsString: string;
begin
   Result := FFieldRecord.Name;
end;

{ TStubField }

class
   function TStubField.GetTypeAsString( aType: TJsonType ): string;
begin
   case aType of
      jtUnknown:
         Result := 'Unknown';
      jtString:
         Result := 'String';
      jtTrue,
         jtFalse:
         Result := 'Boolean';
      jtNumber:
         Result := 'Extended';
      jtDate:
         Result := 'TDate';
      jtDateTime:
         Result := 'TDateTime';
      jtBytes:
         Result := 'Byte';
   end;
end;

constructor TStubField.Create( aParentRecord: TStubRecord; aItemName: string; aFieldType: TJsonType );
begin
   inherited Create;

   if aItemName.Contains( '-' ) then
      raise EJsonMapper.CreateFmt( '%s: Hyphens are not allowed!', [ aItemName ] );

   FParentRecord := aParentRecord;
   FFieldType    := aFieldType;
   Name          := aItemName;

   if FParentRecord <> nil then
      FParentRecord.FItems.add( self );
end;

destructor TStubField.Destroy;
begin
   if FParentRecord <> nil then
      FParentRecord.FItems.Remove( self );
   inherited;
end;

procedure TStubField.SetName( const aValue: string );
begin
   if ( FParentRecord.FArrayProperty <> '' ) AND ( FParentRecord.FArrayProperty = FName ) then
      FParentRecord.FArrayProperty := aValue;

   FAlias := aValue;
   FName  := aValue.SnakeToPascalCase;

   FFieldName := FName;

   if ReservedWords.Contains( aValue.ToLower ) then
      FFieldName := '&' + FFieldName;
end;

function TStubField.GetTypeAsString: string;
begin
   Result := GetTypeAsString( FFieldType );

end;

initialization

PointDsFormatSettings                  := TFormatSettings.Create( );
PointDsFormatSettings.DecimalSeparator := '.';

ReservedWords := TList<string>.Create;
ReservedWords.add( 'type' );
ReservedWords.add( 'for' );
ReservedWords.add( 'var' );
ReservedWords.add( 'begin' );
ReservedWords.add( 'end' );
ReservedWords.add( 'function' );
ReservedWords.add( 'procedure' );
ReservedWords.add( 'object' );
ReservedWords.add( 'interface' );
ReservedWords.add( 'private' );
ReservedWords.add( 'public' );
ReservedWords.add( 'protected' );
ReservedWords.add( 'class' );
ReservedWords.add( 'record' );
ReservedWords.add( 'string' );
ReservedWords.add( 'initialization' );
ReservedWords.add( 'finalization' );

finalization

FreeAndNil( ReservedWords );

end.
