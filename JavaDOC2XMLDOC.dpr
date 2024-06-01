/// <summary>
///   Command line tool to convert the JavaDoc comments of a Delphi unit into
///   XMLDOC comments.
///
///   (c) 01.06.2024 - 2024 Markus Humm
///   All rights reserved
/// </summary>
program JavaDOC2XMLDOC;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes;

var
  SourceContents,
  TargetContents,
  CommentBlock  : TStringList;

  InComment     : Boolean; // Are we in a JavaDoc comment block?
  TrimmedLine   : string;

  Ident         : Integer; // number of space chars to ident the comments
  LineCount     : Integer; // Number of the line we're in

/// <summary>
///   Adds a XMLDOC comment to a StringList
/// </summary>
/// <param name="sl">
///   The list to add the comment to
/// </param>
/// <param name="Name">
///   XMLDOC section name
/// </param>
/// <param name="Contents">
///   The actual comment to add
/// </param>
/// <param name="Ident">
///   Number of chars the block shall be idented
/// </param>
/// <param name="Param">
///   Optional parameter, used for specifying the parameter in a param node
/// </param>
procedure AddXMLDOCComment(sl             : TStringList;
                           const Name     : string;
                           const Contents : string;
                           Ident          : UInt8;
                           const Param    : string = '');
var
  IdentStr : string;
  Lines    : TStringList;
begin
  SetLength(IdentStr, Ident);
  IdentStr := IdentStr.PadLeft(Ident);

  Lines    := TStringList.Create;

  try
    Lines.Text := Contents;

    sl.Add(IdentStr + '/// <' + Name + Param + '>');

    for var s in Lines do
      sl.Add(IdentStr + '/// ' + s);

    sl.Add(IdentStr + '/// </' + Name + '>');
  finally
    Lines.Free;
  end;
end;

/// <summary>
///   Adds a XMLDOC summary comment to a StringList
/// </summary>
/// <param name="sl">
///   The list to add the comment to
/// </param>
/// <param name="Contents">
///   The actual comment to add
/// </param>
/// <param name="Ident">
///   Number of chars the block shall be idented
/// </param>
procedure AddSummary(sl             : TStringList;
                     const Contents : string;
                     Ident          : UInt8);
begin
  AddXMLDOCComment(sl, 'summary', Contents, Ident);
end;

/// <summary>
///   Adds a XMLDOC returns comment to a StringList
/// </summary>
/// <param name="sl">
///   The list to add the comment to
/// </param>
/// <param name="Contents">
///   The actual comment to add
/// </param>
/// <param name="Ident">
///   Number of chars the block shall be idented
/// </param>
procedure AddReturns(sl             : TStringList;
                     const Contents : string;
                     Ident          : UInt8);
begin
  AddXMLDOCComment(sl, 'returns', Contents, Ident);
end;

/// <summary>
///   Adds a XMLDOC param comment to a StringList
/// </summary>
/// <param name="sl">
///   The list to add the comment to
/// </param>
/// <param name="Name">
///   Name of the parameter
/// </param>
/// <param name="Contents">
///   The actual comment to add
/// </param>
/// <param name="Ident">
///   Number of chars the block shall be idented
/// </param>
procedure AddParam(sl             : TStringList;
                   const Name     : string;
                   const Contents : string;
                   Ident          : UInt8);
begin
  AddXMLDOCComment(sl, 'param', Contents, Ident, ' name="' + Name +'"');
end;

/// <summary>
///   Checks whether a given string is the start of a certain javaDoc comment block section
/// </summary>
/// <param name="s">
///   String to check
/// </param>
/// <param name="Name">
///   Section name to look for
/// </param>
/// <returns>
///   true if it is and it is not commented out, false otherwise
/// </returns>
function IsStartOfJavaDocSection(const s : string;
                                 const Name : string): Boolean;
var
  IdxSection,
  IdxComment : Integer;
begin
  IdxSection := s.ToUpper.IndexOf(Name.ToUpper);
  IdxComment := s.IndexOf('//');

  Result := (IdxSection >= 0) and ((IdxSection < IdxComment) or (IdxComment < 0));
end;

/// <summary>
///   Processes the contents of a JavaDoc summary section
/// </summary>
/// <param name="Line">
///   Current line of the processed input
/// </param>
/// <param name="Summary">
///   In this var parameter the complete description is being collected
/// </param>
procedure ProcessSummaryJavaDocComment(const Line  : string;
                                       var Summary : string);
begin
  // We are not at the beginning of the next section so just add the line
  if ((not IsStartOfJavaDocSection(Line, 'Parameters:')) and
     (not IsStartOfJavaDocSection(Line, 'Returns:'))) then
  begin
    // do not add the "Description" line, just the description.
    if not Line.Trim.ToUpper.StartsWith('DESCRIPTION:') then
      Summary := Summary + sLineBreak + Line;
  end
  else
  begin
    // As this is the end of the block we need to create the summary
    // XMLDOC comment

    // Remove the line break at the start of the string
    Summary := Summary.Replace(sLineBreak, '', []);
    AddSummary(TargetContents, Summary, Ident);
  end;
end;

/// <summary>
///   Processes the contents of a JavaDoc returns section
/// </summary>
/// <param name="Line">
///   Current line of the processed input
/// </param>
/// <param name="Param">
///   In this var parameter the complete description is being collected
/// </param>
/// <param name="ParamName">
///   Name of the currently processed parameter
/// </param>
procedure ProcessParameterJavaDocComment(const Line    : string;
                                         var Param     : string;
                                         var ParamName : string);
begin
  if (not IsStartOfJavaDocSection(Line, 'Returns:')) then
  begin
    // we have a new parameter, so extract the name first
    if IsStartOfJavaDocSection(Line, ' - ') then
    begin
      // Output of previous param
      if not ParamName.IsEmpty then
        AddParam(TargetContents, ParamName, Param, Ident);

      ParamName := Line.Remove(Line.IndexOf(' - ')).Trim;
      Param     := ' ' + Line.Remove(0, Line.IndexOf(' - ') + 2);
    end
    else
      Param := sLineBreak + Param + Line;
  end
  else
    AddParam(TargetContents, ParamName, Param, Ident);
end;

/// <summary>
///   Processes the contents of a JavaDoc returns section
/// </summary>
/// <param name="Line">
///   Current line of the processed input
/// </param>
/// <param name="Returns">
///   In this var parameter the complete description is being collected
/// </param>
procedure ProcessReturnsJavaDocComment(const Line  : string;
                                       var Returns : string);
begin
  // End of the complete JavaDoc comment
  if (not IsStartOfJavaDocSection(Line, '}')) then
    Returns := Returns + sLineBreak + Line
  else
  begin
    // Remove the line break at the start of the string
    Returns := Returns.Replace(sLineBreak, '', []);

    if (not (Returns = '  None.')) then
      AddReturns(TargetContents, Returns, Ident);
  end;
end;

/// <summary>
///   Parses the extracted JavaDoc comment block and inserts the generated XMLDOC
///   comments into the TargetContents string list.
/// </summary>
procedure ProcessCommentBlock;
var
  Summary,
  Param,
  Returns : string;

  ParamName : string; // Name of the currently processed parameter

  IsSummary,
  IsReturns,
  IsParameter : Boolean;

  procedure ClearFlags;
  begin
    IsSummary   := false;
    IsReturns   := false;
    IsParameter := false;
  end;
begin
  ClearFlags;

  for var Line in CommentBlock do
  begin
    // We are inside a summary section
    if IsSummary then
      ProcessSummaryJavaDocComment(Line, Summary);

    if IsParameter then
      ProcessParameterJavaDocComment(Line, Param, ParamName);

    if IsReturns then
      ProcessReturnsJavaDocComment(Line, Returns);

    // Line marks the start of a summary block, which is not commented out
    if IsStartOfJavaDocSection(Line, 'Summary:') then
    begin
      Summary := '';
      ClearFlags;
      IsSummary := true;
    end
    else
      if IsStartOfJavaDocSection(Line, 'Parameters:') then
      begin
        Param := '';
        ParamName := '';
        ClearFlags;
        IsParameter := true;
      end
      else
        if IsStartOfJavaDocSection(Line, 'Returns:') then
        begin
          Returns := '';
          ClearFlags;
          IsReturns := true;
        end;
  end;

  CommentBlock.Clear;
end;

/// <summary>
///   Returns the number of leaching space chars in the given string
/// </summary>
/// <param name="s">
///   String to count the chars in
/// </param>
/// <returns>
///   Number of leading space chars
/// </returns>
function GetLeadingSpaceCount(const s : string): UInt32;
begin
  Result := 0;

  for var i := 1 to s.Length do
  begin
    if (s[i] = ' ') then
      inc(Result)
    else
      break;
  end;
end;

begin
  if (ParamCount <> 2) then
  begin
    WriteLn('Convert JavaDoc style comments to XMLDOC comments');
    WriteLn;
    WriteLn('This tool must be called with a source and a destination pascal file name.');
    WriteLn('The source file must exist, the destination file will be created, but');
    WriteLn('its path must exist! File names/paths containing spaces need to be put in  ""');
    WriteLn;
    WriteLn('JavaDOC2XMLDOC <SourceFile> <TargetFile>');
    WriteLn;
    WriteLn('Press Enter to quit');
    ReadLn;
    Halt(1);
  end;

  SourceContents := TStringList.Create;
  TargetContents := TStringList.Create;
  CommentBlock   := TStringList.Create;

  try
    try
      InComment := false;
      LineCount := 0;

      SourceContents.LoadFromFile(ParamStr(1));

      for var Line in SourceContents do
      begin
        // Are we in a comment block, or does this line start a comment block?
        if InComment or (Line.Contains('{@@') and not Line.Contains('//')) then
        begin
          TrimmedLine := Line.Trim;
          CommentBlock.Add(Line);

          // Is this the end of the comment block?
          if TrimmedLine.EndsWith('}') and not TrimmedLine.StartsWith('//') then
          begin
            InComment := false;
            // Determine ident by next source line's leading space chars
            if (SourceContents.Count > LineCount) then
              Ident := GetLeadingSpaceCount(SourceContents[LineCount + 1]);

            ProcessCommentBlock;
          end
          else
            InComment := true;
        end
        else
          // No, so take it as it is
          TargetContents.Add(Line);

        inc(LineCount);
      end;

      TargetContents.SaveToFile(ParamStr(2));
    except
      on E: Exception do
        Writeln(E.ClassName, ': ', E.Message);
    end;
  finally
    SourceContents.Free;
    TargetContents.Free;
    CommentBlock.Free;
  end;
end.
