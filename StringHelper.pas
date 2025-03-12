unit StringHelper;

interface

uses System.SysUtils;

type
   TStringHelper = record helper for
      string

   const
      Empty = '';
   private
   public

      function Apply( const aName: string; aValue: string ): String; overload;
      function Apply( const aPairs: array of variant ): String; overload;
      function ParamApply( const aParam: string; aValue: string ): String; overload;
      function ParamApply( const aParams: array of variant ): String; overload;
      function MacroApply( const aMacro: string; aValue: string ): String; overload;
      function MacroApply( const aMacros: array of variant ): String; overload;

      function Base64Encode: string;
      function Base64Decode: string;
      function AsInteger: Integer;
      function Contains( const Value: string ): Boolean;
      function HasError: Boolean;
      function IndexOf( const Value: string ): Integer;
      function GetLength: Integer;
      function Lower: string;
      function QuotedString: string;
      function Trim: string;
      function TrimLeft: string;
      function TrimRight: string;
      function ToLower: string;
      function ToUpper: string;
      function Upper: string;
      function SnakeToPascalCase: string;
      function StartsWith( const aValue: string; aIgnoreCase: Boolean ): Boolean;
      function StringToEnumString( aPrefix: string = '' ): string;

      function Replace( aOldValue, aNewValue: string ): string;

      property Length: Integer read GetLength;
   end;

   TVariantHelper = record helper for variant
      function toString( const aNoUseSingleQuotes: Boolean = true ): string;
   end;

implementation

uses
   System.StrUtils, System.Variants, System.RegularExpressions, System.NetEncoding;

{ TStringHelper }

function TStringHelper.ParamApply( const aParam: string; aValue: string ): String;
const
   CHARACTER: string = ':';
begin
   Result := StringReplace( Self, CHARACTER + aParam, aValue, [ rfReplaceAll ] );
end;

function TStringHelper.ParamApply( const aParams: array of variant ): String;
var
   I: Integer;
begin
   Result    := Self;
   for I     := 0 to ( System.Length( aParams ) div 2 ) - 1 do
      Result := Result.ParamApply( aParams[ 2 * I ], aParams[ 2 * I + 1 ].toString );
end;

function TStringHelper.MacroApply( const aMacro: string; aValue: string ): String;
const
   CHARACTER: string = '!';
begin
   Result := StringReplace( Self, CHARACTER + aMacro, aValue, [ rfReplaceAll ] );
end;

function TStringHelper.MacroApply( const aMacros: array of variant ): String;
var
   I: Integer;
begin
   Result    := Self;
   for I     := 0 to ( System.Length( aMacros ) div 2 ) - 1 do
      Result := Result.MacroApply( aMacros[ 2 * I ], aMacros[ 2 * I + 1 ].toString );
end;

function TStringHelper.Apply( const aPairs: array of variant ): String;
begin
   Result := Self.ParamApply( aPairs ).MacroApply( aPairs );
end;

type
   TMatchEvaluators = class
      class function Match( const Match: TMatch ): string;
   end;

class function TMatchEvaluators.Match( const Match: TMatch ): string;
begin
   Result := Match.Groups[ 1 ].Value.Upper;
end;

function TStringHelper.StringToEnumString( aPrefix: string = '' ): string;
begin
   Result := Self.Lower.Trim;
   Result := TRegEx.Create( '[^a-zA-Z0-9]([a-zA-Z])' ).Replace( Result, TMatchEvaluators.Match );
   if Result <> '' then
      Result[ 1 ] := UpCase( Result[ 1 ] );

   Result := TRegEx.Create( '[^a-zA-Z0-9]' ).Replace( Result, '' );
end;

function TStringHelper.SnakeToPascalCase: string;
var
   Regex: TRegEx;
begin
   Result := Self.Lower;
   Regex  := TRegEx.Create( '_([a-zA-Z])' );
   Result := Regex.Replace( Self, TMatchEvaluators.Match );
   if Result <> '' then
      Result[ 1 ] := UpCase( Result[ 1 ] );
end;

function TStringHelper.ToLower: string;
begin
   Result := System.SysUtils.Lowercase( Self );
end;

function TStringHelper.ToUpper: string;
begin
   Result := System.SysUtils.UpperCase( Self );
end;

function TStringHelper.Trim: string;
begin
   Result := System.SysUtils.Trim( Self );
end;

function TStringHelper.TrimLeft: string;
begin
   Result := System.SysUtils.TrimLeft( Self );
end;

function TStringHelper.TrimRight: string;
begin
   Result := System.SysUtils.TrimRight( Self );
end;

function TStringHelper.Base64Encode: string;
begin
   Result := TNetEncoding.Base64.Encode( Self );
end;

function TStringHelper.Base64Decode: string;
begin
   Result := TNetEncoding.Base64.Decode( Self );
end;

function TStringHelper.AsInteger: Integer;
begin
   if not TryStrToInt( Self, Result ) then
      Result := 0;
end;

function TStringHelper.Contains( const Value: string ): Boolean;
begin
   Result := System.Pos( Value, Self ) > 0;
end;

function TStringHelper.HasError: Boolean;
begin
   Result := not SameStr( Self.Trim, EmptyStr );
end;

function TStringHelper.IndexOf( const Value: string ): Integer;
begin
   Result := System.Pos( Value, Self ) - 1;
end;

function TStringHelper.GetLength: Integer;
begin
   Result := System.Length( Self );
end;

function TStringHelper.Lower: string;
begin
   Result := Self.ToLower;
end;

function TStringHelper.QuotedString: string;
begin
   Result := System.SysUtils.QuotedStr( Self );
end;

function TStringHelper.Replace( aOldValue, aNewValue: string ): string;
begin
   Result := StringReplace( Self, aOldValue, aNewValue, [ rfReplaceAll ] );
end;

function TStringHelper.Upper: string;
begin
   Result := Self.ToUpper;
end;

function TStringHelper.StartsWith( const aValue: string; aIgnoreCase: Boolean ): Boolean;
begin
   if aValue = Empty then
      Result := true
   else if aIgnoreCase then
      Result := StartsText( aValue, Self )
   else
      Result := IndexOf( aValue ) = 0;
end;

function TStringHelper.Apply( const aName: string; aValue: string ): String;
begin
   Result := Self.ParamApply( [ aName, aValue ] ).MacroApply( [ aName, aValue ] );
end;

{ TVariantHelper }
function TVariantHelper.toString( const aNoUseSingleQuotes: Boolean = true ): string;
const
   DATE_FORMAT      = 'dd/mm/yyyy';
   DATE_TIME_FORMAT = DATE_FORMAT + ' hh:nn:ss.zzz';

   DEFAULT_NULL_STRING: string          = '';
   DEFAULT_BOOLEAN_TRUE_STRING: string  = 'True';
   DEFAULT_BOOLEAN_FALSE_STRING: string = 'False';
   DEFAULT_DECIMAL_SEPARATOR_US: Char   = '.';
   DEFAULT_DATE_TIME_ZERO: string       = '30/12/1899 00:00:00.000';
   DEFAULT_TIME_ZERO: string            = ' 00:00:00.000';
   SINGLE_QUOTES: string                = #39;

var
   LDecimalSeparatorOld: Char;
   LValue              : variant;
   LDateTime           : TDatetime;
   LTrimToNull         : Boolean;
   LDateTimeFormat     : string;
   LQuoteDate          : Boolean;
   LQuoteDateChar      : Char;
   LNullString         : string;
   LTrueString         : string;
   LFalseString        : string;
   LUseSingleQuotes    : Boolean;
begin
   Result           := EmptyStr;
   LUseSingleQuotes := not aNoUseSingleQuotes;
   LTrimToNull      := true;
   LDateTimeFormat  := DATE_TIME_FORMAT;
   LQuoteDate       := LUseSingleQuotes;
   LQuoteDateChar   := '''';
   LNullString      := '';
   LTrueString      := 'True';
   LFalseString     := 'False';

   LValue := Self;

   if SameStr( Trim( LNullString ), EmptyStr ) then
      LNullString := DEFAULT_NULL_STRING;

   case AnsiIndexText( VarTypeAsText( VarType( LValue ) ), [ 'FMTBcdVariantType' ] ) of
      0:
         LValue := VarAsType( LValue, varDouble );
   end;

   if VarIsOrdinal( LValue ) then
   begin
      Result := VarToStr( LValue );

      if SameText( Result, DEFAULT_BOOLEAN_TRUE_STRING ) then
         if LUseSingleQuotes then
            Result := QuotedStr( LTrueString );

      if SameText( Result, DEFAULT_BOOLEAN_FALSE_STRING ) then
         if LUseSingleQuotes then
            Result := QuotedStr( LFalseString );
   end;

   if VarIsFloat( LValue ) then
      with System.SysUtils.FormatSettings, FormatSettings do
      begin
         LDecimalSeparatorOld := DecimalSeparator;
         DecimalSeparator     := DEFAULT_DECIMAL_SEPARATOR_US;
         Result               := FloatToStrF( LValue, ffFixed, 18, 2, FormatSettings );
         Result               := StringReplace( Result, '.00', EmptyStr, [ rfReplaceAll, rfIgnoreCase ] );
         DecimalSeparator     := LDecimalSeparatorOld;
      end;

   if VarIsStr( LValue ) then
   begin
      Result := LValue;
      if LUseSingleQuotes then
         Result := QuotedStr( Result );
   end;

   if SameStr( Result, EmptyStr ) then
      if VarIsType( LValue, varDate ) { varDate } or TryStrToDateTime( VarToStr( LValue ), LDateTime ) { varSQLDatetime } then
      begin
         Result := IFThen(
            LQuoteDate,
            AnsiQuotedStr( FormatDateTime( LDateTimeFormat, VarToDateTime( LValue ) ), LQuoteDateChar ),
            FormatDateTime( LDateTimeFormat, VarToDateTime( LValue ) )
            );
         Result := StringReplace( Result, QuotedStr( DEFAULT_DATE_TIME_ZERO ), LNullString, [ ] );
         Result := StringReplace( Result, DEFAULT_TIME_ZERO, EmptyStr, [ ] );
      end;

   if ( ( VarIsClear( LValue ) ) or ( VarIsNull( LValue ) ) or ( VarIsEmpty( LValue ) ) or ( VarIsError( LValue ) ) ) then
      Result := LNullString;

   if not LTrimToNull then
      exit;

   if ( SameStr( Result, EmptyStr ) ) then
      exit( LNullString );

   if ( SameStr( StringReplace( Result, SINGLE_QUOTES, EmptyStr, [ rfReplaceAll ] ), EmptyStr ) ) then
      Result := LNullString;
end;

end.
