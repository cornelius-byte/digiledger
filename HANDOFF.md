# Project Handoff: Flutter Receipt Scanner (PaddleOCR / NCNN)

## Project Context & Tech Stack
- **Framework:** Flutter (Android) with native C++ OCR integration (`ppocrv5ncnn.cpp` / PaddleOCR NCNN in `fast_paddle_ocr`).
- **Key Files:**
    - `lib/screens/receipt_scanner_screen.dart` (Camera viewfinder & capture UI)
    - `lib/services/ocr_service.dart` (OCR inference `sizeid = 3` / 560px, amount extraction, merchant filtering, `suggestCategoryName()`)
    - `lib/screens/add_transaction_screen.dart` (Autofill form & confirmation banner)
    - Native C++ file: `C:/Users/User/AppData/Local/Pub/Cache/hosted/pub.dev/fast_paddle_ocr-0.0.5/android/src/main/jni/ppocrv5ncnn.cpp`
    - `test/ocr_service_test.dart` (Unit tests)

## Completed Tasks
1. **Live Camera Preview & Native Detection Cleaned:**
    - Modified `ppocrv5ncnn.cpp` to check `is_photo_mode` before feeding preview frames to the detection thread (`det_thread_loop`).
    - Removed the continuous green bounding box drawing loop in `on_image_render` during `is_photo_mode`.
    - Added natural document reading-order sorting (top-to-bottom, left-to-right) for detected OCR boxes in `Java_com_iweka_ocr_PPOCRv5Ncnn_ocrFromImage`, ensuring bounding boxes and recognized text retain logical line-by-line structure.
2. **Merchant Name Prefix Cleanup:**
    - Added `_cleanMerchantName()` in `ocr_service.dart` to automatically strip label prefixes like `Merchant-`, `Merchant:`, `Vendor:`, `Store Name:`, `Business Name:`, etc.
    - Updated `_extractVendorName()` so prefixes such as `Merchant-Jeeve's` cleanly extract as `Jeeve's`.
3. **Receipt Total Amount Parser Hardening:**
    - Enhanced `_extractTotalAmount()` and added `_extractAmountFromTotalLine()` to handle real-world receipt variations:
        - Amounts directly adjacent to total keywords on single or multi-column lines (e.g., `TOTAL: $21.08 CASH: $30.00 CHANGE: $8.92`).
        - Spaces around decimal separators caused by OCR fragmentation (e.g., `TOTAL 21 . 08`).
        - Integer totals with currency indicators (e.g., `TOTAL: $25`).
        - Multi-line separated totals (e.g., `TOTAL` followed by `USD` and amount).
        - OCR character typos (e.g., `T0TAL` with zero).
        - European decimal comma notations (e.g., `24,50`).
        - Excluding lines with items/quantities (e.g., `TOTAL ITEMS: 3`) from being mistaken for amounts.
4. **Unit Tests & Verification:**
    - Updated `test/ocr_service_test.dart` with test suites covering `Merchant-Jeeve's`, `Store Name:`, spaced decimals, multi-line totals, integer totals, and OCR typos (11/11 tests passing).
    - Ran `flutter test --no-pub` (11/11 passed).
    - Ran `flutter build apk --debug --no-pub` (built cleanly in 87.6s with 0 errors).
