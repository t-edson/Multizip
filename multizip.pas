program multizip;
{Program to compress files.
 Based on: http://wiki.freepascal.org/paszlib
}
uses
  Classes, SysUtils, zipper, CustApp, SplitFile;
const
  {$I version.txt}
var
  OurZipper: TZipper;
type

  { TMyApplication }

  TMyApplication = class(TCustomApplication)
  protected
    listFiles: TSTringList;
    listPars: TStringList;
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;
procedure TMyApplication.DoRun;
const
  SHORT_OPTS = 'ho:s:';
  LONG_OPTS : array [1..3] of string = ('help', 'output:', 'size');
var
  ErrorMsg, str, strSize, dirPath, relPath: String;
  i: Integer;
  outFile, baseName: RawByteString;
  strm: TMemoryStream;
  partSize: Longint;
  isDirectory: Boolean;
begin
  // Check parameters
  ErrorMsg := CheckOptions(SHORT_OPTS, LONG_OPTS);
  if ErrorMsg <> '' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // Check by help
  if HasOption('h', 'help') or (ParamCount = 0) then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  // Check file name
  GetNonOptions(SHORT_OPTS, LONG_OPTS, listPars);
  if listPars.Count = 0 then begin
    // No files
    writeln('No input files specified.');
    Terminate;
    Exit;
  end else if listPars.Count = 1 then begin
    // One name (could be one or more files)
    //Obtain list of input files
    listFiles.Clear;
    ExpandFileName(listPars[0], listFiles, isDirectory, dirPath);
    if listFiles.Count = 0 then begin
      writeln('No input files found: ' + listPars[0]);
      Terminate;
      Exit;
    end;
  end else begin
    // Several file names
    //Obtain list of input files
    listFiles.Clear;
    for i := 0 to listPars.Count -1 do begin
      ExpandFileName(listPars[i], listFiles, isDirectory, dirPath);
      writeln('Processing file: ' + listPars[i]);
    end;
    if listFiles.Count = 0 then begin
      writeln('No input files found: ' + listPars[0]);
      Terminate;
      Exit;
    end;
    //Here, for simplicity, we consider the list of files is not directories, even if
    //the list can contain one or more directory.
    isDirectory := false;
  end;
  //Obtain name of output file
  if HasOption('o', 'output') or (ParamCount = 0) then begin
    //A name has been specified
    outFile := GetOptionValue('o', 'output');
  end else begin
    //We should choose a name
    if isDirectory then begin
      outFile := listPars[0] + '.zip';
    end else begin
      if listFiles.Count = 1 then begin
        //It's just one file
        outFile := ChangeFileExt(listPars[0], '.zip');
      end else begin
        outFile := ChangeFileExt(listFiles[0], '.zip');  //Take the first name
      end;
    end;
  end;
  //Compress files
  OurZipper := TZipper.Create;
  try
    OurZipper.FileName := outFile;
    if isDirectory then begin
      for str in listFiles do begin
        if dirPath = '' then begin  //Folder in the current directory
          relPath := str;
          OurZipper.Entries.AddFileEntry(str, relPath);
        end else begin
          //Cut the initial path. So if the path is c:\someDir\targetDir\a.txt,
          //we will obtain: targetDir\a.txt
          relPath := copy(str, length(dirPath)+2, 255);
          OurZipper.Entries.AddFileEntry(str, relPath);
        end;
        writeln('Compressing: ' + relPath);
      end;
    end else begin
      for str in listFiles do begin
        OurZipper.Entries.AddFileEntry(str, ExtractFileName(str));
        writeln('Compressing: ' + relPath);
      end;
    end;
    if HasOption('s', 'size') then begin
      //Compress and split
      strSize := GetOptionValue('s', 'size');
      if not TryStrToInt(strSize, partSize) then begin
        writeln('Bad file size: ' + strSize);
        Terminate;
        Exit;
      end;
      //Compress to a stream
      strm := TMemoryStream.Create;
      OurZipper.SaveToStream(strm);
      baseName := ExtractFileName(outFile);
      baseName := ChangeFileExt(baseName, '');
      DoSplitFile(strm, baseName, partSize * 1024, ExtractFileName(outFile), '.zp');
      strm.Destroy;
      //Using a file
      //OurZipper.SaveToFile(outFile);
      //DoSplitFile(outFile, partSize*1024);
    end else begin
      //Just compress
      OurZipper.SaveToFile(outFile);
      //OurZipper.ZipAllFiles;
    end;
  finally
    OurZipper.Free;
  end;
  if listFiles.Count = 1 then begin
    writeln('1 file compressed.');
  end else begin
    writeln(listFiles.Count, ' files compressed.');
  end;
  // stop program loop
  Terminate;
end;
constructor TMyApplication.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException := True;
  listPars := TStringList.Create;
  listFiles := TStringList.Create;
end;
destructor TMyApplication.Destroy;
begin
  FreeAndNil(listFiles);
  FreeAndNil(listPars);
  inherited Destroy;
end;
procedure TMyApplication.WriteHelp;
var
  filName: string;
begin
  writeln('');
  writeln('                === MULTIZIP ' + VER_PROG + ' ===');
  writeln('By ' + 'Tito Hinostroza - 2018 - All right reserved.');
  writeln('Utility to compress and split files or folders.');
  writeln('');
  write  ('SYNTAX: ');
  filName := ExtractFileName(ExeName);
  writeln('  ' + filName + ' <input files> [optional parameters]');
  writeln('');
  writeln('Optional parameters can be: ');
  writeln('');
  writeln('-h or --help');
  writeln('  Print help information.');
  writeln('-o <file name> or --output=<filename>');
  writeln('  Set output file name. If not specified, a default name will be used.');
  writeln('-s <max.size> or --size=<max.size>');
  writeln('  Split the compressed file in files of "max.size" kilobytes.');
  writeln('');
  writeln('Example 1: Compress the file this.txt to this.zip');
  writeln('  ' + filName + ' this.txt' );
  writeln('');
  writeln('Example 2: Compress the files 1.txt and 2.txt to 12.zip');
  writeln('  ' + filName + ' 1.txt 2.txt -o 12.zip' );
  writeln('');
  writeln('Example 3: Compress all the *.txt files to text.zip');
  writeln('  ' + filName + ' *.txt -o text.zip' );
  writeln('');
  writeln('Example 4: Compress an split the file a.txt in parts of 10KB');
  writeln('  ' + filName + ' a.txt -s 10' );
  writeln('');
  writeln('Compressed files will be saved as the standard name *.zip.');
  writeln('');
  writeln('Compressed and splitted files will be saved as several names with a number');
  writeln('as ordinal: *.0.zp *.1.zp *.2.zp...');
end;
var
  Application: TMyApplication;

begin
  Application := TMyApplication.Create(nil);
  Application.Title := 'Multizip';
  Application.Run;
  Application.Free;
end.
