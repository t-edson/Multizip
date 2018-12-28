unit SplitFile;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils;
type
  THeader = record
    id: word;
    nblock : byte;
    nblocks: byte;
    filsize: DWord;
  end;

function DoSplitFile(sourceFile: string; partSize: integer): string;
function DoSplitFile(sourceStrm: TStream; baseName: string; partSize: integer): string;

implementation

procedure WritePartFile(const buffer; bufsize: integer;
                        nblock, nblocks: byte; filName: string);
var
  strm: TStream;
  header: THeader;
begin
  header.ID := $4243;

  header.nblock  := nblock;
  header.nblocks := nblocks;
  strm := TFileStream.Create(filName, fmCreate);
  try
    strm.Write(header, SizeOf(THeader));
    strm.Write(buffer, bufsize);
  finally
    strm.Free;
  end;
end;
function DoSplitFile(sourceStrm: TStream; baseName: string; partSize: integer): string;
var
  vBuffer: Pointer;
  nRead: LongInt;
  nFiles, nbloque: integer;
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
  partSize := partSize - SizeOf(THeader);  //leave space to header.
  //Write parts
  GetMem(vBuffer, partSize);
  if sourceStrm is TMemoryStream then begin
    ms := TMemoryStream(sourceStrm);
    //We need to use ReadBuffer().
    ms.Position := 0;
    for nbloque := 0 to nFiles - 1 do begin
      //Create part
      nRead := ms.Size - ms.Position;
      if nRead > partSize then nRead := partSize;
      ms.ReadBuffer(vBuffer^, nRead);
      partName := baseName + '.' + IntToStr(nbloque) + '.part';
      WritePartFile(vBuffer^, nRead, nbloque, nFiles, partName);
    end;
  end else begin
    for nbloque := 0 to nFiles - 1 do begin
      //Create part
      nRead := sourceStrm.Read(vBuffer^, partSize);
      partName := baseName + '.' + IntToStr(nbloque) + '.part';
      WritePartFile(vBuffer^, nRead, nbloque, nFiles, partName);
    end;
  end;
end;

function DoSplitFile(sourceFile: string; partSize: integer): string;
var
  strm: TFileStream;
  vBuffer: Pointer;
  nRead: LongInt;
  nFiles, nbloque: integer;
  partName: String;
begin
  strm := TFileStream.Create(sourceFile, fmOpenRead + fmShareDenyNone);
  Result := DoSplitFile(strm, 'aaa', partSize);
  strm.Destroy;
end;

end.

