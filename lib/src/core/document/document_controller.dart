export 'controllers/base_document_controller.dart';
export 'controllers/block_document_controller.dart';
export 'controllers/text_document_controller.dart';
export 'controllers/formatting_document_controller.dart';
export 'controllers/list_document_controller.dart';
export 'controllers/table_document_controller.dart';
export 'controllers/image_document_controller.dart';
export 'controllers/search_document_controller.dart';

import 'controllers/search_document_controller.dart';

/// Editing operations on the [Document] model.
///
/// This is the unified engine combining base document state, block management,
/// text editing, formatting, lists, table operations, image blocks, and search & replace features.
///
/// Feature breakdown across the inheritance hierarchy:
/// - [BaseDocumentController]: Document model, history (undo/redo), serialization, lifecycle.
/// - [BlockDocumentController]: Block splitting, merging, conversion, and reordering.
/// - [TextDocumentController]: Text insertion, deletion, updating, and span manipulation.
/// - [FormattingDocumentController]: Inline formatting, hyperlinks, alignment, and format state.
/// - [ListDocumentController]: Bullet and numbered lists, indentation, and custom bullet styling.
/// - [TableDocumentController]: Table creation, cell modifications, rows, columns, and cell formatting.
/// - [ImageDocumentController]: Image insertion, size, alignment, and deletion with atomic undo/redo.
/// - [SearchDocumentController]: Live search matching, regex parsing, and atomic replacements.
class DocumentController extends SearchDocumentController {
  DocumentController({
    super.document,
    super.undoRedoManager,
  });
}
