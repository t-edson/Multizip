unit SplitFile;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils;
type
  THeader = record
    //id      : word;
    nblock  : byte;
    nblocks : byte;
    filsize : DWord;  //Just informative
    blksize : DWord;
    namesize: byte;   //Length of the original file name
  end;
  THeaderPtr = ^Theader;

procedure ExpandFileName(fileName: string; lstOfFiles: TStringList);
function DoSplitFile(sourceFile: string; partSize: integer): string;
function DoSplitFile(sourceStrm: TStream; baseName: string; partSize: integer;
                     origFileName, extent: string): string;
function DoJoinFiles(partFile: string; out outFile: string): string;

implementation
procedure ExpandFileName(fileName: string; lstOfFiles: TStringList);
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

procedure WritePartFile(const buffer; bufsize: integer; nblock, nblocks: byte;
                        filName: string; origFileName: string);
var
  strm: TStream;
  header: THeader;
begin
  strm := TFileStream.Create(filName, fmCreate);
  header.nblock  := nblock;
  header.nblocks := nblocks;
  header.filsize := strm.Size;
  header.blksize := bufsize;
  header.namesize := length(origFileName) * SizeOf(Char);
  try
    //Write header
    strm.Write(header, SizeOf(THeader));
    //Write file name
    strm.Write(Pointer(origFileName)^, Length(origFileName) * SizeOf(Char) );
    //Write data
    strm.Write(buffer, bufsize);
  finally
    strm.Free;
  end;
end;
function DoSplitFile(sourceStrm: TStream; baseName: string; partSize: integer;
                     origFileName, extent: string): string;
var
  vBuffer: Pointer;
  nRead: LongInt;
  nFiles, nblock: integer;
  partName: String;
  ms: TMemoryStream;
begin
  Result := '';
  //Calculate number of files
  nFiles := sourceStrm.Size div partSize;
  if sourceStrm.Size mod partSize <> 0 then inc(nFiles);
  if partSize < SizeOf(THeader) then begin
    Result := 'Too small size of file.';
    exit;
  end;
  if nFiles>255 then begin
    Result := 'Too many files to generate. Increase the size of parts.';
    exit;
  end;
  //Leave space to header abd teh file name.
  partSize := partSize - SizeOf(THeader) - length(origFileName);
  //Write parts
  GetMem(vBuffer, partSize);
  if sourceStrm is TMemoryStream then begin
    ms := TMemoryStream(sourceStrm);
    //We need to use ReadBuffer().
    ms.Position := 0;
    for nblock := 0 to nFiles - 1 do begin
      //Create part
      nRead := ms.Size - ms.Position;
      if nRead > partSize then nRead := partSize;
      ms.ReadBuffer(vBuffer^, nRead);
      partName := baseName + '.' + IntToStr(nblock) + extent;
      WritePartFile(vBuffer^, nRead, nblock, nFiles, partName, origFileName);
    end;
  end else begin
    for nblock := 0 to nFiles - 1 do begin
      //Create part
      nRead := sourceStrm.Read(vBuffer^, partSize);
      partName := baseName + '.' + IntToStr(nblock) + extent;
      WritePartFile(vBuffer^, nRead, nblock, nFiles, partName, origFileName);
    end;
  end;
end;
function ReadHeaderFile(fileName: string; headPtr: THeaderPtr; out srcName: string): string;
var
  FileStream: TFileStream;
begin
  Result := '';
  FileStream := TFileStream.Create(fileName, fmOpenRead);
  try
    //Read information of header
    FileStream.ReadBuffer(headPtr^, SizeOf(THeader));
    //Read file name
    SetLength(srcName, (headPtr^.namesize div SizeOf(Char)));
    FileStream.ReadBuffer(Pointer(srcName)^, headPtr^.namesize);
  finally
    FreeAndNil(FileStream);
  end;
end;
function ReadDataFile(fileName: string; data: Pointer; out nRead: integer): string;
var
  FileStream: TFileStream;
  head      : Theader;
  srcName   : string;
begin
  Result := '';
  FileStream := TFileStream.Create(fileName, fmOpenRead);
  try
    //Read information of header
    FileStream.ReadBuffer(head, SizeOf(THeader));
    //Read file name
    SetLength(srcName, (head.namesize div SizeOf(Char)));
    FileStream.ReadBuffer(Pointer(srcName)^, head.namesize);
    //Read data of block
    FileStream.ReadBuffer(data^, head.blksize);
    nRead := head.blksize;
  finally
    FreeAndNil(FileStream);
  end;
end;
function DoJoinFiles(partFile: string; out outFile: string): string;
const
  EXTENT = '.part';
var
  nPart: Longint;
  tmp, srcName: String;
  dotPos1, i, dotPos2, nRead: Integer;
  header: THeader;
  vBuffer: pointer;
  strm: TFileStream;
begin
  Result := '';
  if UpCase(ExtractFileExt(partFile)) <> UpCase(EXTENT) then begin
    Result := 'Unknown file type.';
    exit;
  end;
  //Is a "part" file. Get the number of part:  name.0.part
  dotPos2 := length(partFile) - length(EXTENT) + 1;  //The last dot in the file Name
  dotPos1 := dotPos2 - 1;
  while (dotPos1>1) and (partFile[dotPos1]<>'.') do dec(dotPos1);
  if dotPos1<=1 then begin
    Result := 'Bad format in file name.';
    exit;
  end;
  tmp := copy(partFile, dotPos1+1, dotpos2-dotpos1-1);  //Expected no more of 4 digits
  if not TryStrToInt(tmp, nPart) then begin
    Result := 'Bad format in file name.';
    exit;
  end;
  //Find the part 0 of the files
  if nPart = 0 then begin
    //This is the number 0
  end else begin
    partFile := copy(partFile, 1, dotPos1) + '0' + EXTENT;
  end;
  if not FileExists(partFile) then begin
    Result := 'Not found: ' + partFile;
    exit;
  end;
  //Extract information from part 0
  Result := ReadHeaderFile(partFile, @header, srcName);
  if Result<>'' then begin
    exit;
  end;
  outFile := srcName;
  GetMem(vBuffer, header.blksize);  //We're assuming the part0 must be the biggest size.
  //Join the data from files
  strm := TFileStream.Create(outFile, fmCreate);
  try
    for i:=0 to header.nblocks - 1 do begin
      partFile := copy(partFile, 1, dotPos1) + IntToStr(i) + EXTENT;
      if not FileExists(partFile) then begin
        Result := 'Not found: ' + partFile;
        exit;
      end;
      Result := ReadDataFile(partFile, vBuffer, nRead);
      if Result<>'' then begin
        exit;
      end;
      strm.WriteBuffer(vBuffer^, nRead);
    end;
  finally
    strm.Free;
  end;
end;
function DoSplitFile(sourceFile: string; partSize: integer): string;
var
  strm: TFileStream;
  origFileName, baseName: RawByteString;
begin
  strm := TFileStream.Create(sourceFile, fmOpenRead + fmShareDenyNone);
  origFileName := ExtractFileName(sourceFile);
  baseName := ExtractFilePath(sourceFile) + ExtractFileName(sourceFile);
  Result := DoSplitFile(strm, baseName, partSize, origFileName, '.part');
  strm.Destroy;
end;

end.

