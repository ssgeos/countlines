{
  countlines: Counts lines in *.pas, *.pp, *.dpr, and *.lfm files
  - PAS/PP/DPR: Non-empty (TotalLines), Code (incl. code with // comments), Comment (TotalLines - CodeLines), Empty
  - LFM: Total lines, Empty lines
  - Supports comment blocks
  - Ignores nested/malformed comments (bad practice)
  - Warns on unclosed comment blocks
  - Single-pass file reading, CSV output
  - Safeguard for empty directories
  copyright (C) Frank Hoogerbeets (https://github.com/ssgeos/)
  License: FPC modified LGPL Version 2 (https://wiki.lazarus.freepascal.org/FPC_modified_LGPL)
}
program countlines;

uses
  SysUtils;

type TSource = record
  CodeLines: integer;
  CommentLines: integer;
  EmptyLines: integer;
  TotalLines: integer;
end;

var
  Directory: string;
  PasFile: TSource;
  LfmFile: TSource;
  PasFilesTotal: TSource;
  LfmFilesTotal: TSource;

procedure CountLinesInFile(const FileName: string; var Source: TSource);
// count code lines
var
  F: TextFile;
  Line: string;
  InCommentBlock: Boolean;
  TrimmedLine: string;
  i: Integer;
begin
  InCommentBlock := False;

  AssignFile(F, FileName);
  try
    Reset(F);
    while not EOF(F) do
      begin
        ReadLn(F, Line);
        TrimmedLine := Trim(Line);

        if Trim(Line) = '' then
          begin
            Inc(Source.EmptyLines);
            Continue;
          end;

        Inc(Source.TotalLines);

        // Check for single-line // comment
        if not InCommentBlock then
          begin
            i := Pos('//', TrimmedLine);
            if i > 0 then
              begin
                TrimmedLine := Trim(Copy(TrimmedLine, 1, i - 1));
                if TrimmedLine = '' then
                  Continue;
              end;
          end;

        // Handle multi-line comment blocks
        if InCommentBlock then
          begin
            i := Pos('}', TrimmedLine);
            if i = 0 then
              i := Pos('*)', TrimmedLine);
            if i > 0 then
              begin
                InCommentBlock := False;
                TrimmedLine := Trim(Copy(TrimmedLine, i + 1, Length(TrimmedLine)));
                if TrimmedLine = '' then
                  Continue;
              end
            else
              Continue;
          end;

        // Check for start of multi-line comment block
        i := Pos('{', TrimmedLine);
        if i = 0 then
          i := Pos('(*', TrimmedLine);
        if i > 0 then
          begin
            if Pos('}', TrimmedLine) > i then
              begin
                TrimmedLine := Trim(Copy(TrimmedLine, 1, i - 1) +
                                    Copy(TrimmedLine, Pos('}', TrimmedLine) + 1, Length(TrimmedLine)));
                if TrimmedLine = '' then
                  Continue;
              end
            else if Pos('*)', TrimmedLine) > i then
              begin
                TrimmedLine := Trim(Copy(TrimmedLine, 1, i - 1) +
                                    Copy(TrimmedLine, Pos('*)', TrimmedLine) + 1, Length(TrimmedLine)));
                if TrimmedLine = '' then
                  Continue;
              end
            else
              begin
                InCommentBlock := True;
                TrimmedLine := Trim(Copy(TrimmedLine, 1, i - 1));
                if TrimmedLine = '' then
                  Continue;
              end;
          end;

        // Count non-empty, non-comment lines
        if TrimmedLine <> '' then
          Inc(Source.CodeLines);
      end;
    if InCommentBlock then
      Writeln('WARNING: Unclosed comment block in ', FileName);
  except
    on E: Exception do
      Writeln('Error reading file ', FileName, ': ', E.Message);
  end;
  CloseFile(F);
end;

procedure CountFilesInDirectory(const Directory: string);
var
  SearchRec: TSearchRec;
  FilePath, Ext: string;
begin
  // reset totals
  PasFilesTotal := default(TSource);
  LfmFilesTotal := default(TSource);

  if FindFirst(IncludeTrailingPathDelimiter(Directory) + '*.*', faAnyFile, SearchRec) = 0 then
    try
      repeat
        if (SearchRec.Attr and faDirectory) = 0 then
          begin
            FilePath := IncludeTrailingPathDelimiter(Directory) + SearchRec.Name;
            Ext := LowerCase(ExtractFileExt(SearchRec.Name));
            // source code units
            if (Ext = '.pas') or (Ext = '.pp') or (Ext = '.dpr') then
              begin
                PasFile := default(TSource);
                CountLinesInFile(FilePath, PasFile);
                Inc(PasFilesTotal.TotalLines, PasFile.TotalLines);
                Inc(PasFilesTotal.EmptyLines, PasFile.EmptyLines);
                Inc(PasFilesTotal.CodeLines, PasFile.CodeLines);
                PasFile.CommentLines := PasFile.TotalLines - PasFile.CodeLines;
                Inc(PasFilesTotal.CommentLines, PasFile.CommentLines);
                Writeln(
                  'File: ', SearchRec.Name,
                  ', Total Lines (non-empty): ', PasFile.TotalLines,
                  ', Code Lines: ', PasFile.CodeLines,
                  ', Comment Lines: ', PasFile.CommentLines,
                  ', Empty Lines: ', PasFile.EmptyLines
                );
              end
            // auto-generated form files
            else if Ext = '.lfm' then
              begin
                LfmFile := default(TSource);
                CountLinesInFile(FilePath, LfmFile);
                Inc(LfmFilesTotal.TotalLines, LfmFile.TotalLines);
                Inc(LfmFilesTotal.EmptyLines, LfmFile.EmptyLines);
                Writeln(
                  'File: ', SearchRec.Name,
                  ', Total Lines: ', LfmFile.TotalLines,
                  ', Empty Lines: ', LfmFile.EmptyLines
                );
              end;
          end;
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
end;

procedure SaveCountsToCSV(const Directory: string);
var
  F: TextFile;
  SearchRec: TSearchRec;
  FilePath, Ext: string;
begin
  try
    AssignFile(F, Directory + '/line_counts.csv');
    Rewrite(F);
    Writeln(F, 'File,NonEmpty,Code,Comment,Empty');
    if FindFirst(IncludeTrailingPathDelimiter(Directory) + '*.*', faAnyFile, SearchRec) = 0 then
			try
				repeat
				  if (SearchRec.Attr and faDirectory) = 0 then
				    begin
				      FilePath := IncludeTrailingPathDelimiter(Directory) + SearchRec.Name;
				      Ext := LowerCase(ExtractFileExt(SearchRec.Name));
				      if Ext = '.pas' then
				        begin
				          PasFile := default(TSource);
				          CountLinesInFile(FilePath, PasFile);
				          Writeln(F, SearchRec.Name + ',' +
				                  IntToStr(PasFile.TotalLines) + ',' +
				                  IntToStr(PasFile.CodeLines) + ',' +
				                  IntToStr(PasFile.TotalLines - PasFile.CodeLines) + ',' +
				                  IntToStr(PasFile.EmptyLines));
				        end
				      else if Ext = '.lfm' then
				        begin
				          LfmFile := default(TSource);
				          CountLinesInFile(FilePath, LfmFile);
				          Writeln(F, SearchRec.Name + ',' +
				                  IntToStr(LfmFile.TotalLines) + ',,,' +
				                  IntToStr(LfmFile.EmptyLines));
				        end;
				    end;
				until FindNext(SearchRec) <> 0;
			finally
				FindClose(SearchRec);
			end;
			Writeln(F, 'Total PAS,' + IntToStr(PasFilesTotal.TotalLines) + ',' +
				        IntToStr(PasFilesTotal.CodeLines) + ',' +
				        IntToStr(PasFilesTotal.CommentLines) + ',' +
				        IntToStr(PasFilesTotal.EmptyLines));
			Writeln(F, 'Total LFM,' + IntToStr(LfmFilesTotal.TotalLines) + ',,,' +
				        IntToStr(LfmFilesTotal.EmptyLines));
      if PasFilesTotal.TotalLines > 0 then
        begin
          Writeln(F);
          Writeln(F, '# Comment lines percentage (of non-empty): ', (PasFilesTotal.CommentLines / PasFilesTotal.TotalLines * 100):0:1, '%');
          Writeln(F, '# Empty lines percentage (of total): ', (PasFilesTotal.EmptyLines / (PasFilesTotal.TotalLines + PasFilesTotal.EmptyLines) * 100):0:1, '%');
        end;
      CloseFile(F);
  except
    on E: Exception do
      Writeln('Error writing CSV: ', E.Message);
  end;
end;

begin
  if ParamCount > 0 then
    Directory := ParamStr(1)
  else
    Directory := GetCurrentDir;

  if not DirectoryExists(Directory) then
    begin
      Writeln('Error: Directory ', Directory, ' does not exist.');
      Halt(1);
    end;

  Writeln('Counting lines in directory: ', Directory);

  CountFilesInDirectory(Directory);
  SaveCountsToCSV(Directory);

  WriteLn;
  Writeln('Total lines in all *.pas files (non-empty): ', PasFilesTotal.TotalLines);
  Writeln('Total code lines (non-comment, non-empty): ', PasFilesTotal.CodeLines);
  Writeln('Total comment lines: ', PasFilesTotal.CommentLines);
  Writeln('Total empty lines: ', PasFilesTotal.EmptyLines);
  if PasFilesTotal.TotalLines > 0 then
    begin
      Writeln('Comment lines percentage (of non-empty): ', (PasFilesTotal.CommentLines / PasFilesTotal.TotalLines * 100):0:1, '%');
      Writeln('Empty lines percentage (of total): ', (PasFilesTotal.EmptyLines / (PasFilesTotal.TotalLines + PasFilesTotal.EmptyLines) * 100):0:1, '%');
    end;
  Writeln('Total lines in all *.lfm files: ', LfmFilesTotal.TotalLines);
  Writeln('Total empty lines: ', LfmFilesTotal.EmptyLines);
  WriteLn;
  WriteLn('Results saved to -> line_counts.csv');
end.
