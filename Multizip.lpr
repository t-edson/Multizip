program Multizip;
{Program to compress files.
 Based on: http://wiki.freepascal.org/paszlib
}
uses
  Classes, SysUtils, zipper, CustApp, SplitFile;
const VERSION = '0.0';
var
  OurZipper: TZipper;
type

  { TMyApplication }

  TMyApplication = class(TCustomApplication)
  private
    procedure ExpandFileName(fileName: string; lstOfFiles: TStringList);
  protected
    listFiles: TSTringList;
    listPars: TStringList;
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;
procedure TMyApplication.ExpandFileName(fileName: string; lstOfFiles: TStringList);
{Expand the fileName to a list of files (in "lstOfFiles") considering the wildcard
chars: "?" or "*". The list of files will be added to "lstOfFiles", without a previous
clearing.}
var
  Info: TSearchRec;
begin
  if fileName = '' then exit;
  //There are some name
  if (pos('*', fileName) = 0) and (pos('?', fileName) = 0) then begin
    //It's just a file name.
    lstOfFiles.Add(fileName);  //No check for existence.
    exit;
  end;
  //There are some wildcard chars.
  if FindFirst(fileName, faAnyFile and faDirectory, Info)=0 then begin
    Repeat
      if (Info.Attr and faDirectory) = faDirectory then begin
        //Could be "." or ".."
      end else begin
        lstOfFiles.Add(Info.Name);
      end;
    until FindNext(info)<>0;
  end;
  FindClose(Info);
end;
procedure TMyApplication.DoRun;
const
  SHORT_OPTS = 'ho:s:';
  LONG_OPTS : array [1..3] of string = ('help', 'output:', 'size');
var
  ErrorMsg, str, strSize: String;
  i: Integer;
  outFile, baseName: RawByteString;
  strm: TMemoryStream;
  partSize: Longint;
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
    ExpandFileName(listPars[0], listFiles);
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
      ExpandFileName(listPars[i], listFiles);
      writeln('Processing file: ' + listPars[i]);
    end;
    if listFiles.Count = 0 then begin
      writeln('No input files found: ' + listPars[0]);
      Terminate;
      Exit;
    end;
  end;
  //Obtain name of output file
  if HasOption('o', 'output') or (ParamCount = 0) then begin
    //A name has been specified
    outFile := GetOptionValue('o', 'output');
  end else begin
    //We should choose a name
    if listFiles.Count = 1 then begin
      //It's just one file
      outFile := ChangeFileExt(listPars[0], '.zip');
    end else begin
      outFile := ChangeFileExt(listFiles[0], '.zip');  //Take the first name
    end;
  end;
  //Compress files
  OurZipper := TZipper.Create;
  try
    OurZipper.FileName := outFile;
    for str in listFiles do
      OurZipper.Entries.AddFileEntry(str, str);
    if HasOption('s', 'size') then begin
      //Compress and split
      strSize := GetOptionValue('s', 'size');
      if not TryStrToInt(strSize, partSize) then begin
        writeln('Bad file size: ' + strSize);
        Terminate;
        Exit;
      end;
      //Uisng stream
      strm := TMemoryStream.Create;
      OurZipper.SaveToStream(strm);
      baseName := ExtractFileName(outFile);
      baseName := ChangeFileExt(baseName, '');
      DoSplitFile(strm, baseName, partSize * 1024);
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
  writeln('                 MULTIZIP ' + VERSION);
  writeln('                 ===========');
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
  writeln('Example1: Compress the file this.txt to this.zip');
  writeln('  ' + filName + ' this.txt' );
  writeln('');
  writeln('Example1: Compress the files 1.txt and 2.txt to 12.zip');
  writeln('  ' + filName + ' 1.txt 2.txt -o 12.zip' );
  writeln('');
  writeln('Example1: Compress all the *.txt files to text.zip');
  writeln('  ' + filName + ' *.txt -o text.zip' );
end;
var
  Application: TMyApplication;

begin
  Application := TMyApplication.Create(nil);
  Application.Title := 'Multizip';
  Application.Run;
  Application.Free;
end.
