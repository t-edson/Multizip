program multiunzip;
{Program to compress files.
 Based on: http://wiki.freepascal.org/paszlib
}
uses
  Classes, SysUtils, zipper, CustApp, SplitFile;
const
  {$I version.txt}
var
  UnZipper: TUnZipper;
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
  SHORT_OPTS = 'hf:';
  LONG_OPTS : array [1..2] of string = ('help','folder');
var
  ErrorMsg, inFile, extFile, err, outFile, dirPath: String;
  outFolder: RawByteString;
  IsDir: boolean;
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
    ExpandFileName(listPars[0], listFiles, IsDir, dirPath);
    if listFiles.Count = 0 then begin
      writeln('No input files found: ' + listPars[0]);
      Terminate;
      Exit;
    end;
    if listFiles.Count > 1 then begin
      writeln('No multiple files allowed.');
      Terminate;
      Exit;
    end;
  end else begin
    // Several file names
    writeln('No multiple files allowed.');
    Terminate;
    exit;
  end;
  inFile := listFiles[0];  //name of output file
  //Get folder output
  if HasOption('f', 'folder') then begin
    //A folder has been specified
    outFolder := GetOptionValue('f', 'folder');
  end else begin
    //Default folder
    outFolder := ExtractFilePath(inFile);
  end;
  // Process file
  extFile := UpCase(ExtractFileExt(inFile));
  if extFile = '.ZIP' then begin
    //Must be extracted
    UnZipper := TUnZipper.Create;
    try
      UnZipper.FileName := inFile;
      UnZipper.OutputPath := outFolder;
      UnZipper.Examine;
      UnZipper.UnZipAllFiles;
    finally
      UnZipper.Free;
    end;
  end else if extFile = '.PART' then begin
    //Must be joined
    err := DoJoinFiles(inFile, outFile);
    if err<>'' then begin
      writeln(err);
      Terminate;
      exit;
    end;
  end else if extFile = '.ZP' then begin
    //Must be joined and uncompressed
    err := DoJoinFiles(inFile, outFile);
    if err<>'' then begin
      writeln(err);
      Terminate;
      exit;
    end;
    //Uncompress
    UnZipper := TUnZipper.Create;
    try
      UnZipper.FileName := outFile;
      UnZipper.OutputPath := outFolder;
      UnZipper.Examine;
      UnZipper.UnZipAllFiles;
    finally
      UnZipper.Free;
    end;
    DeleteFile(outFile);
  end else begin
    //Unknown file
    writeln('Unknown file type.');
    Terminate;
    exit;
  end;

//  if listFiles.Count = 1 then begin
//    writeln('1 file compressed.');
//  end else begin
//    writeln(listFiles.Count, ' files compressed.');
//  end;
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
  writeln('               === MULTIUNZIP ' + VER_PROG + ' ===');
  writeln('By ' + 'Tito Hinostroza - 2018 - All right reserved.');
  writeln('Utility to uncompress and join files or folders compressed or splitted');
  writeln('by MULTIZIP.');
  writeln('');
  write  ('SYNTAX: ');
  filName := ExtractFileName(ExeName);
  writeln('  ' + filName + ' <input file> [optional parameters]');
  writeln('');
  writeln('<input file> is the compressed file. For join splitted files, only the');
  writeln('*.0.part must be indicated');
  writeln('');
  writeln('Optional parameters can be: ');
  writeln('');
  writeln('-h or --help');
  writeln('  Print help information.');
  writeln('-f <folder name> or --folder=<fodler name>');
  writeln('  Set output folder where extract compressed files. If not specified, it.');
  writeln('  will be used the same folder of the compressed file.');
  writeln('');
  writeln('Example 1: Uncompress the file this.zip to this.zip');
  writeln('  ' + filName + ' this.zip' );
  writeln('');
  writeln('Example 2: Join the files text.0.part, text.1.part, ...');
  writeln('  ' + filName + ' text.0.part' );
end;
var
  Application: TMyApplication;

begin
  Application := TMyApplication.Create(nil);
  Application.Title := 'MultiUnzip';
  Application.Run;
  Application.Free;
end.
