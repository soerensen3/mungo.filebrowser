unit mungo.filebrowser;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,

  Dialogs,
  LCLType,

  mungo.intf.editor,
  Controls,
  ExtCtrls,
  StdCtrls,
  Forms,

  FileUtil,
  mungo.intf.FilePointer,
  laz.VirtualTrees,
  mungo.components.colors,
  mungo.components.FileBrowser,
  mungo.components.base,

  LazFileUtils;

type
  { TFileBrowserNewFileDialog }

  TFileBrowserNewFileDialog = class ( TForm )
    private
      FFileName: String;
      FShowBrowseButton: Boolean;
      FBrowseButton: TButton;
      procedure OnBrowseButtonClick(Sender: TObject);
      procedure OnEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
      procedure OnEditKeyPress(Sender: TObject; var Key: char);
      procedure SetFileName(AValue: String);
      procedure SetShowBrowseButton(AValue: Boolean);

    published
      Edit: TEdit;

    public
      constructor CreateNew(TheOwner: TComponent; Num: Integer = 0 ); override;

      function ShowModal: Integer; override;
      property FileName: String read FFileName write SetFileName;
      property ShowBrowseButton: Boolean read FShowBrowseButton write SetShowBrowseButton;
  end;

  { TFileBrowser }

  TFileBrowser = class ( TEditorTool )
    private
      FActFileNew, FActFileNewDir, FActViewRefresh, FActFileAddSearchPath: TAction;

      procedure ActionFileNewDirectory(Sender: TObject);
      procedure ActionViewRefresh(Sender: TObject);
      function GetSearchPaths: TFilePointerList;
      procedure ActionFileNew(Sender: TObject);
      procedure ActionAddSearchPath( Sender: TObject );

    public
      FileTree: TVirtualStringTreeFileBrowser;
      Images: TImageList;
      ClickTimer: TTimer;
      NewFileDlg: TFileBrowserNewFileDialog;

      procedure FileTreeClick(Sender: TObject);
      procedure FileTreeDblClick(Sender: TObject);
      procedure FileTreeClickTimer(Sender: TObject);

      procedure OpenFile( ANode: PVirtualNode; APersistent: Boolean );

      procedure UpdateFolders;

      procedure AddSearchPath( AFileName: String );

      constructor Create; override;
      destructor Destroy; override;

      class function GetToolName: String; override;

      property SearchPaths: TFilePointerList read GetSearchPaths;
  end;


implementation

{ TFileBrowserNewFileDialog }

procedure TFileBrowserNewFileDialog.SetFileName(AValue: String);
begin
  FFileName:= AValue;
  if ( Assigned( Edit )) then
    Edit.Text:= FFileName;
end;

procedure TFileBrowserNewFileDialog.SetShowBrowseButton(AValue: Boolean);
begin
  if FShowBrowseButton=AValue then Exit;
  FShowBrowseButton:=AValue;
  FBrowseButton.Visible:= AValue;
end;

procedure TFileBrowserNewFileDialog.OnEditKeyPress(Sender: TObject; var Key: char);
begin

end;

procedure TFileBrowserNewFileDialog.OnEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if ( Key = VK_RETURN ) then
    ModalResult:= mrOK
  else if ( Key = VK_ESCAPE ) then
    ModalResult:= mrCancel;
end;

procedure TFileBrowserNewFileDialog.OnBrowseButtonClick(Sender: TObject);
var
  OpenDialog: TOpenDialog;
begin
  OpenDialog:= TOpenDialog.Create( Self );
  OpenDialog.FileName:= Edit.Text;
  if ( OpenDialog.Execute ) then
    Edit.Text:= OpenDialog.FileName;
  OpenDialog.Free;
end;

constructor TFileBrowserNewFileDialog.CreateNew(TheOwner: TComponent; Num: Integer);
begin
  inherited CreateNew( TheOwner, Num );
//  if ( not Assigned( Edit )) then
    Edit:= TEdit.Create( Self );

  Edit.Parent:= Self;
  Edit.Align:= alClient;
  Edit.OnKeyDown:=@OnEditKeyDown;
  Width:= 400;
  Height:= 30;
  Position:= poMainFormCenter;
  BorderStyle:= bsSizeToolWin;
  Constraints.MaxHeight:= 30;
  Constraints.MinHeight:= 30;

  FBrowseButton:= TButton.Create( Self );
  FBrowseButton.Caption:= '...';
  FBrowseButton.Align:= alRight;
  FBrowseButton.Parent:= Self;
  FBrowseButton.Width:= 30;
  FBrowseButton.Accent:= True;
  FBrowseButton.ShowImage:= False;
  FBrowseButton.OnClick:=@OnBrowseButtonClick;
  ShowBrowseButton:= False;
end;

function TFileBrowserNewFileDialog.ShowModal: Integer;
begin
{  if ( not Assigned( Edit )) then
    Edit:= TEdit.Create( Self );

  Edit.Parent:= Self;
  Edit.Align:= alClient;
  Edit.Text:= FileName;
  Edit.OnKeyDown:=@OnEditKeyDown;
  Width:= 400;
  Height:= 30;
  Position:= poMainFormCenter;
  BorderStyle:= bsDialog;}

  Edit.Text:= FileName;
  Result:=inherited ShowModal;
  FFileName:= Edit.Text;
end;

{ TFileBrowser }

procedure TFileBrowser.UpdateFolders;
begin
  FileTree.UpdateFolders;
end;

procedure TFileBrowser.AddSearchPath(AFileName: String);
var
  P: TFilePointer;
begin
  P:= FilePointers.GetFilePointer( AFileName );
  SearchPaths.Add( P );
end;

procedure TFileBrowser.ActionFileNewDirectory(Sender: TObject);
  function GetRootNodeForChild( ANode: PVirtualNode ): PVirtualNode;
  var
    Node: PVirtualNode;
  begin
    Result:= nil;
    Node:= ANode;
    while ( Assigned( Node ) and ( Node <> FileTree.RootNode )) do begin
      Result:= Node;
      Node:= Node^.Parent;
    end;
  end;

var
  Data, RtData: PTreeData;
  RtNode: PVirtualNode;
  RootDir, FileName: String;
begin
  if ( not Assigned( NewFileDlg )) then begin
    NewFileDlg:= TFileBrowserNewFileDialog.CreateNew( TComponent( Control ));
    NewFileDlg.Hide;
  end;
  if ( Assigned( FileTree.FocusedNode )) then begin
    RtNode:= GetRootNodeForChild( FileTree.FocusedNode );
    Data:= FileTree.GetNodeData( FileTree.FocusedNode );
    RtData:= FileTree.GetNodeData( RtNode );
    RootDir:= RtData^.FullName;
    case ( Data^.FileType ) of
      FT_FILE_GENERIC: NewFileDlg.FileName:= AppendPathDelim( CreateRelativePath( ExtractFilePath( Data^.FullName ), RootDir ));
      FT_FOLDER: NewFileDlg.FileName:= AppendPathDelim( CreateRelativePath( Data^.FullName, RootDir ));
      FT_FOLDER_ROOT: NewFileDlg.FileName:= '';
    else;
    end;
  end else
    exit;

  if ( NewFileDlg.ShowModal = mrOK ) then begin
    FileName:= CreateAbsolutePath( NewFileDlg.FileName, RootDir );
    ForceDirectoriesUTF8( FileName );
  end;
end;

function TFileBrowser.GetSearchPaths: TFilePointerList;
begin
  Result:= FileTree.SearchPaths;
end;

procedure TFileBrowser.ActionFileNew(Sender: TObject);
  function GetRootNodeForChild( ANode: PVirtualNode ): PVirtualNode;
  var
    Node: PVirtualNode;
  begin
    Result:= nil;
    Node:= ANode;
    while ( Assigned( Node ) and ( Node <> FileTree.RootNode )) do begin
      Result:= Node;
      Node:= Node^.Parent;
    end;
  end;

var
  Data, RtData: PTreeData;
  RtNode: PVirtualNode;
  RootDir, FileName: String;
begin
  if ( not Assigned( NewFileDlg )) then begin
    NewFileDlg:= TFileBrowserNewFileDialog.CreateNew( TComponent( Control ));
    NewFileDlg.Hide;
  end;
  if ( Assigned( FileTree.FocusedNode )) then begin
    RtNode:= GetRootNodeForChild( FileTree.FocusedNode );
    Data:= FileTree.GetNodeData( FileTree.FocusedNode );
    RtData:= FileTree.GetNodeData( RtNode );
    RootDir:= RtData^.FullName;
    case ( Data^.FileType ) of
      FT_FILE_GENERIC: NewFileDlg.FileName:= AppendPathDelim( CreateRelativePath( ExtractFilePath( Data^.FullName ), RootDir ));
      FT_FOLDER: NewFileDlg.FileName:= AppendPathDelim( CreateRelativePath( Data^.FullName, RootDir ));
      FT_FOLDER_ROOT: NewFileDlg.FileName:= '';
    else;
    end;
  end else
    exit;

  if ( NewFileDlg.ShowModal = mrOK ) then begin
    FileName:= CreateAbsolutePath( NewFileDlg.FileName, RootDir );
    ForceDirectoriesUTF8( ExtractFilePath( FileName ));
    if ( not FileExistsUTF8( FileName )) then
      FileClose( FileCreateUTF8( FileName ));
  end;
end;

procedure TFileBrowser.ActionAddSearchPath(Sender: TObject);
  function GetRootNodeForChild( ANode: PVirtualNode ): PVirtualNode;
  var
    Node: PVirtualNode;
  begin
    Result:= nil;
    Node:= ANode;
    while ( Assigned( Node ) and ( Node <> FileTree.RootNode )) do begin
      Result:= Node;
      Node:= Node^.Parent;
    end;
  end;

var
  OpenDialog: TSelectDirectoryDialog;
  RtData: PTreeData;
  RtNode: PVirtualNode;
  RootDir: String;
begin

  OpenDialog:= TSelectDirectoryDialog.Create( nil );
  if ( Assigned( FileTree.FocusedNode )) then begin
    RtNode:= GetRootNodeForChild( FileTree.FocusedNode );
    RtData:= FileTree.GetNodeData( RtNode );
    RootDir:= RtData^.FullName;
    OpenDialog.FileName:= RootDir;
  end else
    OpenDialog.FileName:= ExtractFileDir( GetCurrentDirUTF8 );

  if ( OpenDialog.Execute ) then
    AddSearchPath( OpenDialog.FileName );
  OpenDialog.Free;
end;

procedure TFileBrowser.ActionViewRefresh(Sender: TObject);
begin
  UpdateFolders;
end;

procedure TFileBrowser.FileTreeClick(Sender: TObject);
begin
  ClickTimer.Enabled:= True;
end;

procedure TFileBrowser.FileTreeDblClick(Sender: TObject);
begin
  ClickTimer.Enabled:= False;
  OpenFile( FileTree.FocusedNode, True );
end;

procedure TFileBrowser.FileTreeClickTimer(Sender: TObject);
begin
  ClickTimer.Enabled:= False;
  OpenFile( FileTree.FocusedNode, False );
end;

procedure TFileBrowser.OpenFile(ANode: PVirtualNode; APersistent: Boolean);
var
  Data: PTreeData;
begin
  if ( Assigned( ANode )) then begin
    Data:= FileTree.GetNodeData( ANode );
    if ( Data^.FileType = FT_FILE_GENERIC ) then
      EditorIntf.ActivateOrAddFileTab( FilePointers.GetFilePointer( Data^.FullName ), APersistent );
  end;
end;


constructor TFileBrowser.Create;
var
  Root: TWinControl;

begin
  Root:= Control as TWinControl;
  FileTree:= TVirtualStringTreeFileBrowser.Create( Root );

  FileTree.OnClick:=@FileTreeClick;
  FileTree.OnDblClick:= @FileTreeDblClick;
  FileTree.LineStyle:= lsSolid;
  FileTree.Colors.GridLineColor:= Gray600;

  FileTree.Parent:= TWinControl( Control );
  FileTree.Align:= alClient;
  FileTree.BorderStyle:= bsNone;
  Images:= TImageList.Create( Root );
  FileTree.Images:= Images;
  FileTree.Images.AddResourceName( HINSTANCE, 'FOLDERROOT' );
  FileTree.Images.AddResourceName( HINSTANCE, 'FOLDER' );
  FileTree.Images.AddResourceName( HINSTANCE, 'FILEGENERIC' );
  FileTree.NodeDataSize:= SizeOf( TTreeData );
  ClickTimer:= TTimer.Create( Root );
  ClickTimer.Interval:= 550;
  ClickTimer.Enabled:= False;
  ClickTimer.OnTimer:= @FileTreeClickTimer;

  Images:= TImageList.Create( Root );
  Images.Width:= 16;
  Images.Height:= 16;
  Images.AddResourceName( HINSTANCE, 'DOCUMENT-NEW' );
  Images.AddResourceName( HINSTANCE, 'FOLDER-NEW' );
  Images.AddResourceName( HINSTANCE, 'VIEW-REFRESH' );
  Images.AddResourceName( HINSTANCE, 'FIND-LOCATION' );


  FActFileNew:= TAction.Create( 'New File', @ActionFileNew, 'New File', 0 );
  FActFileNew.Images:= Images;
  FActFileNewDir:= TAction.Create( 'New Directory', @ActionFileNewDirectory, 'New Directory', 1 );
  FActFileNewDir.Images:= Images;
  FActViewRefresh:= TAction.Create( 'Refresh', @ActionViewRefresh, 'Refresh', 2 );
  FActViewRefresh.Images:= Images;
  FActFileAddSearchPath:= TAction.Create( 'Add Searchpath', @ActionAddSearchPath, 'Add Searchpath', 3 );
  FActFileAddSearchPath.Images:= Images;


  ToolBar:= EditorIntf.CreateToolBar( Root );
  ToolBar.AddButton( FActFileNew );
  ToolBar.AddButton( FActFileNewDir );
  ToolBar.AddSpacer();
  ToolBar.AddButton( FActViewRefresh );
  ToolBar.AddButton( FActFileAddSearchPath );
end;

destructor TFileBrowser.Destroy;
begin
  Control:= nil;
  FreeAndNil( FileTree );
  FreeAndNil( Images );
//  FreeAndNil( FSearchPaths );
  FreeAndNil( ClickTimer );
  FreeAndNil( FToolBar );
  inherited Destroy;
end;

class function TFileBrowser.GetToolName: String;
begin
  Result:= 'File Browser';
end;

end.

