//
//  XBookmarkWindowController.m
//  XBookmark
//
//  Created by everettjf on 10/2/15.
//  Copyright © 2015 everettjf. All rights reserved.
//

#import "XBookmarkWindowController.h"
#import "XBookmarkModel.h"
#import "XBookmarkUtil.h"
#import "XBookmarkPreferencesWindowController.h"

@implementation XBookmarkTableCellView
@end

@interface XBookmarkWindowController () <NSTableViewDelegate,NSTableViewDataSource>
@property (weak) IBOutlet NSTableView *bookmarksTableView;
@property (nonatomic,strong) NSArray *bookmarks;
@property (nonatomic,strong) XBookmarkPreferencesWindowController *preferencesWindowController;

@end

@implementation XBookmarkWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.window.level = NSFloatingWindowLevel;
    self.window.hidesOnDeactivate = YES;
    self.bookmarksTableView.action = @selector(onTableViewClick:);
    
    [_bookmarksTableView registerForDraggedTypes:@[@"MyPrivateTableViewDataType"]];

    [self refreshBookmarks];
    
    [[XBookmarkModel sharedModel] addObserver:self forKeyPath:@"bookmarks" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)dealloc {
    [[XBookmarkModel sharedModel] removeObserver:self forKeyPath:@"bookmarks"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    if([keyPath isEqualToString:@"bookmarks"]){
        [self refreshBookmarks];
    }
}

-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    XBookmarkTableCellView *cellView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    if([tableColumn.identifier isEqualToString:@"BookmarkColumn"]){
        XBookmarkEntity *bookmark = [self.bookmarks objectAtIndex:row];
        cellView.titleField.stringValue = [NSString stringWithFormat:@"%@:%lu",[bookmark.sourcePath lastPathComponent],bookmark.lineNumber];
//        cellView.subtitleField.stringValue = bookmark.sourcePath;
    }
    return cellView;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.bookmarks.count;
}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    NSLog(@"rowIndexes %@", rowIndexes);
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:[NSArray arrayWithObject:@"MyPrivateTableViewDataType"] owner:self];
    [pboard setData:data forType:@"MyPrivateTableViewDataType"];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op {
    // Add code here to validate the drop
    return NSDragOperationEvery;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSData *rowData = [pboard dataForType:@"MyPrivateTableViewDataType"];

    NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];

    NSUInteger from = [rowIndexes firstIndex];
    
    NSLog(@"row %zd, from %zd, count %zd", row, from, [XBookmarkModel sharedModel].bookmarks.count);
    if (from > row) {
        // 从下往上
        XBookmarkEntity *bookmark = [XBookmarkModel sharedModel].bookmarks[from];
        [[XBookmarkModel sharedModel] removeBookmark:bookmark.sourcePath lineNumber:bookmark.lineNumber];
        [[XBookmarkModel sharedModel] insertObject:bookmark inBookmarksAtIndex:row];
        [[XBookmarkModel sharedModel] saveBookmarks];
        [self refreshBookmarks];
    } else {
        // 从上往下
        XBookmarkEntity *bookmark = [XBookmarkModel sharedModel].bookmarks[from];
        [[XBookmarkModel sharedModel] removeBookmark:bookmark.sourcePath lineNumber:bookmark.lineNumber];
        [[XBookmarkModel sharedModel] insertObject:bookmark inBookmarksAtIndex:row - 1];
        [[XBookmarkModel sharedModel] saveBookmarks];
        [self refreshBookmarks];
    }
    
    return YES;
}

-(void)refreshBookmarks{
    self.bookmarks = [XBookmarkModel sharedModel].bookmarks;
    [self.bookmarksTableView reloadData];
}

-(XBookmarkEntity*)selectedBookmark{
    NSInteger selectedRow = self.bookmarksTableView.selectedRow;
    if(selectedRow < 0 || selectedRow >= self.bookmarks.count){
        return nil;
    }
    
    XBookmarkEntity *bookmark = [self.bookmarks objectAtIndex:selectedRow];
    return bookmark;
}

-(void)tableViewSelectionDidChange:(NSNotification *)notification{
//    NSLog(@"selection did change");
}
- (IBAction)removeBookmarkClicked:(id)sender {
    XBookmarkEntity *bookmark = [self selectedBookmark];
    if(nil == bookmark)
        return;
    [[XBookmarkModel sharedModel]removeBookmark:bookmark.sourcePath lineNumber:bookmark.lineNumber];
    [[XBookmarkModel sharedModel]saveBookmarks];
}
- (IBAction)clearBookmarkClicked:(id)sender {
    BOOL shouldClear = NO;
    if(_bookmarks.count > 1){
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert setMessageText:@"Clear all bookmarks ?"];
        [alert setAlertStyle:NSWarningAlertStyle];
        if ([alert runModal] == NSAlertFirstButtonReturn) {
            shouldClear = YES;
        }
    }else{
        shouldClear = YES;
    }
    
    if(shouldClear){
        [[XBookmarkModel sharedModel]clearBookmarks];
        [[XBookmarkModel sharedModel]saveBookmarks];
    }
}
- (IBAction)helpClicked:(id)sender {
    NSString *githubURLString = @"http://github.com/everettjf/XBookmark";
    NSString *versionString = [[NSBundle bundleForClass:[XBookmarkWindowController class]]objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *xcodeVersion = [[NSBundle mainBundle]objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Source on GitHub"];
    [alert setMessageText:@"XBookmark"];
    [alert setInformativeText:[NSString stringWithFormat:@"Author:everettjf\nGitHub:%@\nVersion:%@\nXcode:%@",
                               githubURLString,
                               versionString,
                               xcodeVersion
                               ]];
    [alert setAlertStyle:NSWarningAlertStyle];
    NSModalResponse resp = [alert runModal];
    if(resp == NSAlertSecondButtonReturn){
        // Star
        [[NSWorkspace sharedWorkspace]openURL:[NSURL URLWithString:githubURLString]];
    }
}

-(void)onTableViewClick:(id)sender{
//    NSLog(@"row click");
    NSInteger row = self.bookmarksTableView.clickedRow;
    if(row < 0 || row >= self.bookmarks.count)
        return;
    
    XBookmarkEntity *bookmark = [self selectedBookmark];
    if(nil == bookmark)
        return;
    
    // locate bookmark
    [XBookmarkUtil openSourceFile:bookmark.sourcePath highlightLineNumber:bookmark.lineNumber];
}
- (IBAction)showPreferencesClicked:(id)sender {
    self.preferencesWindowController = [[XBookmarkPreferencesWindowController alloc]init];
    [self.preferencesWindowController.window makeKeyAndOrderFront:sender];
}

@end
