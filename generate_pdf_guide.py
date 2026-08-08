import os
import sys
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super(NumberedCanvas, self).__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_header_footer(num_pages)
            super(NumberedCanvas, self).showPage()
        super(NumberedCanvas, self).save()

    def draw_header_footer(self, page_count):
        self.saveState()
        if self._pageNumber > 1:
            # Header
            self.setFont("Helvetica-Bold", 8)
            self.setFillColor(colors.HexColor("#334155"))
            self.drawString(54, 11 * 72 - 36, "SIMS CAFE — COMPLETE ARCHITECTURE, TECHNOLOGIES & TEACHING MANUAL")
            self.setFont("Helvetica", 8)
            self.drawRightString(8.5 * 72 - 54, 11 * 72 - 36, "System Master Reference Guide")
            self.setStrokeColor(colors.HexColor("#CBD5E1"))
            self.setLineWidth(0.75)
            self.line(54, 11 * 72 - 42, 8.5 * 72 - 54, 11 * 72 - 42)

            # Footer
            self.setStrokeColor(colors.HexColor("#E2E8F0"))
            self.setLineWidth(0.75)
            self.line(54, 46, 8.5 * 72 - 54, 46)
            self.setFont("Helvetica", 8)
            self.setFillColor(colors.HexColor("#64748B"))
            self.drawString(54, 32, "SIMS CAFE Management System | POS, ERP & LAN Sync Infrastructure")
            self.drawRightString(8.5 * 72 - 54, 32, f"Page {self._pageNumber} of {page_count}")
        self.restoreState()

def build_pdf(filename="SIMS_Cafe_Master_Architecture_and_Presentation_Guide.pdf"):
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()

    # Cohesive Color Palette
    c_primary = colors.HexColor("#0F172A")    # Deep Slate Navy
    c_secondary = colors.HexColor("#0284C7")  # Sky Blue Accent
    c_teal = colors.HexColor("#0D9488")       # Deep Teal
    c_dark = colors.HexColor("#1E293B")       # Dark Charcoal
    c_muted = colors.HexColor("#64748B")      # Muted Slate
    c_bg_light = colors.HexColor("#F8FAFC")   # Light Row Background
    c_border = colors.HexColor("#CBD5E1")     # Clean Grid Border
    c_callout_bg = colors.HexColor("#F1F5F9") # Callout Background
    c_indigo = colors.HexColor("#4F46E5")

    # Typography Styles
    h1_style = ParagraphStyle(
        'H1',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=14,
        leading=18,
        textColor=c_primary,
        spaceBefore=14,
        spaceAfter=5,
        keepWithNext=True
    )

    h2_style = ParagraphStyle(
        'H2',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10.5,
        leading=14,
        textColor=c_teal,
        spaceBefore=10,
        spaceAfter=4,
        keepWithNext=True
    )

    h3_style = ParagraphStyle(
        'H3',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=9,
        leading=12,
        textColor=c_dark,
        spaceBefore=6,
        spaceAfter=3,
        keepWithNext=True
    )

    body_style = ParagraphStyle(
        'Body',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11.5,
        textColor=c_dark,
        spaceAfter=4
    )

    bullet_style = ParagraphStyle(
        'Bullet',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11.5,
        textColor=c_dark,
        leftIndent=12,
        firstLineIndent=-8,
        spaceAfter=3
    )

    code_style = ParagraphStyle(
        'CodeText',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=7,
        leading=9.5,
        textColor=colors.HexColor("#0F172A")
    )

    callout_style = ParagraphStyle(
        'Callout',
        parent=styles['Normal'],
        fontName='Helvetica-Oblique',
        fontSize=8,
        leading=11,
        textColor=colors.HexColor("#334155")
    )

    table_header_style = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7.5,
        leading=10,
        textColor=colors.white
    )

    table_cell_style = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7,
        leading=9.5,
        textColor=c_dark
    )

    table_cell_bold = ParagraphStyle(
        'TableCellBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7,
        leading=9.5,
        textColor=c_dark
    )

    story = []

    # ══════════════════════════════════════════════════════════════════════════
    # COVER / HEADER BANNER
    # ══════════════════════════════════════════════════════════════════════════
    banner_data = [
        [
            Paragraph("<b>SIMS CAFE MANAGEMENT SYSTEM</b>", ParagraphStyle('BannerTitle', fontName='Helvetica-Bold', fontSize=17, leading=21, textColor=colors.white)),
        ],
        [
            Paragraph("Complete Master Manual: Architecture, Full Library Catalog, Functions, Installation Prerequisites & Teaching Guide", ParagraphStyle('BannerSub', fontName='Helvetica', fontSize=9, leading=12, textColor=colors.HexColor("#93C5FD"))),
        ],
        [
            Paragraph("<b>Deployment Targets:</b> Windows Desktop (x64 EXE & Installer) • Android Mobile & POS Tablets (APK)", ParagraphStyle('BannerMeta', fontName='Helvetica', fontSize=7.5, leading=10, textColor=colors.HexColor("#E2E8F0"))),
        ]
    ]
    banner_table = Table(banner_data, colWidths=[504])
    banner_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#0F172A")),
        ('PADDING', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, -1), (-1, -1), 11),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    story.append(banner_table)
    story.append(Spacer(1, 8))

    # ══════════════════════════════════════════════════════════════════════════
    # 1. EXECUTIVE SUMMARY & ARCHITECTURAL HIGHLIGHTS
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("1. Executive Summary & Project Purpose", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=c_secondary, spaceBefore=2, spaceAfter=5))
    
    exec_summary_text = (
        "<b>SIMS Cafe</b> is a production-grade, enterprise Point-of-Sale (POS) and Restaurant Management ERP ecosystem. "
        "Engineered with <b>Flutter / Dart</b> for responsive multi-platform interfaces and paired with a high-performance <b>.NET 8 C# "
        "companion microservice (CafePrinter.exe)</b> for native Win32 printer spooling, SIMS Cafe eliminates the fatal dependency on active "
        "internet connections in hospitality venues. The system delivers <b>sub-second real-time peer-to-peer LAN synchronization</b> over Wi-Fi "
        "via embedded Shelf HTTP and WebSocket protocols, dual-order numbering, multi-station Kitchen Order Ticket (KOT) dispatching, split tender checkout, "
        "customer credit ledgers (Khata), and expense reconciliation."
    )
    story.append(Paragraph(exec_summary_text, body_style))

    # ══════════════════════════════════════════════════════════════════════════
    # 2. TECHNOLOGIES & LIBRARIES CATALOG
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("2. Complete Technology Stack & Detailed Library Catalog", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=c_secondary, spaceBefore=2, spaceAfter=5))

    story.append(Paragraph(
        "Below is the complete, categorized breakdown of all programming languages, frameworks, Flutter packages, and .NET libraries used in SIMS Cafe along with their exact functional role:",
        body_style
    ))

    # Table 1: Core Framework, State & Local Storage
    story.append(Paragraph("A. Core Framework, State Management & Database Libraries", h2_style))
    lib_data_1 = [
        [Paragraph("<b>Library / Dependency</b>", table_header_style), Paragraph("<b>Version</b>", table_header_style), Paragraph("<b>Specific Role & Use in SIMS Cafe</b>", table_header_style)],
        [
            Paragraph("<b>flutter & dart</b>", table_cell_bold),
            Paragraph("v3.29 / 3.7+", table_cell_style),
            Paragraph("Core cross-platform UI rendering engine, reactive widget tree, event loop, and Dart runtime on Windows and Android.", table_cell_style)
        ],
        [
            Paragraph("<b>provider</b>", table_cell_bold),
            Paragraph("^6.1.2", table_cell_style),
            Paragraph("App-wide state management via <code>ChangeNotifier</code>. Powers 10 decoupled state managers: <code>OrderProvider</code>, <code>MenuProvider</code>, <code>TableProvider</code>, <code>LanSyncProvider</code>, <code>SettingsProvider</code>, etc.", table_cell_style)
        ],
        [
            Paragraph("<b>sqflite</b>", table_cell_bold),
            Paragraph("^2.3.3", table_cell_style),
            Paragraph("Native SQLite database driver for Android mobile and POS tablets, managing local CRUD operations and transactions.", table_cell_style)
        ],
        [
            Paragraph("<b>sqflite_common_ffi</b>", table_cell_bold),
            Paragraph("^2.3.0", table_cell_style),
            Paragraph("C-FFI SQLite loader for Windows Desktop (<code>cafeapp.exe</code>), enabling high-speed local database operations on PC.", table_cell_style)
        ],
        [
            Paragraph("<b>shared_preferences</b>", table_cell_bold),
            Paragraph("^2.3.3", table_cell_style),
            Paragraph("Key-value persistence for app configuration: printer IP/ports, server host/client mode toggle, store profile, and UI preferences.", table_cell_style)
        ],
        [
            Paragraph("<b>flutter_secure_storage</b>", table_cell_bold),
            Paragraph("^9.0.0", table_cell_style),
            Paragraph("Encrypted storage for sensitive secrets: admin master PIN, API keys, and device authorization tokens.", table_cell_style)
        ],
        [
            Paragraph("<b>path_provider & path</b>", table_cell_bold),
            Paragraph("^2.1.4 / ^1.9.0", table_cell_style),
            Paragraph("Resolves OS-specific stable storage paths (<code>AppData/Roaming</code> on Windows, app sandbox on Android) to ensure data persists across app updates.", table_cell_style)
        ]
    ]
    lib_table_1 = Table(lib_data_1, colWidths=[110, 55, 339])
    lib_table_1.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#0F172A")),
        ('PADDING', (0, 0), (-1, -1), 3),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, c_bg_light]),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(lib_table_1)
    story.append(Spacer(1, 6))

    # Table 2: Networking & LAN Sync
    story.append(Paragraph("B. Real-Time Networking, LAN Sync & Cloud Libraries", h2_style))
    lib_data_2 = [
        [Paragraph("<b>Library / Dependency</b>", table_header_style), Paragraph("<b>Version</b>", table_header_style), Paragraph("<b>Specific Role & Use in SIMS Cafe</b>", table_header_style)],
        [
            Paragraph("<b>shelf & shelf_router</b>", table_cell_bold),
            Paragraph("^1.4.1 / ^1.1.4", table_cell_style),
            Paragraph("Embedded HTTP microserver running inside the host application on Port 8642. Serves REST endpoints for node handshake, full sync, and incremental sync.", table_cell_style)
        ],
        [
            Paragraph("<b>shelf_web_socket & web_socket_channel</b>", table_cell_bold),
            Paragraph("^2.0.1 / ^3.0.1", table_cell_style),
            Paragraph("WebSocket communication pipeline for sub-second real-time event broadcasting (e.g. <code>ORDER_CREATED</code>, <code>TABLE_OCCUPIED</code>) to all connected waiter tablets.", table_cell_style)
        ],
        [
            Paragraph("<b>http & connectivity_plus</b>", table_cell_bold),
            Paragraph("^1.3.0 / ^6.0.3", table_cell_style),
            Paragraph("HTTP client for cloud API communication and live network state listener detecting Wi-Fi/Ethernet disconnects and triggering auto-reconnection.", table_cell_style)
        ],
        [
            Paragraph("<b>network_info_plus</b>", table_cell_bold),
            Paragraph("^5.0.3", table_cell_style),
            Paragraph("Extracts local Wi-Fi IP address (e.g. <code>192.168.1.100</code>) to broadcast server location to peer devices during auto-discovery.", table_cell_style)
        ],
        [
            Paragraph("<b>firebase_core & firestore</b>", table_cell_bold),
            Paragraph("^3.4.1 / ^5.0.0", table_cell_style),
            Paragraph("Cloud Firestore for online store registration, license validity verification, and remote telemetry.", table_cell_style)
        ],
        [
            Paragraph("<b>firedart</b>", table_cell_bold),
            Paragraph("^0.9.8", table_cell_style),
            Paragraph("Pure Dart Firestore implementation used as fallback for Windows desktop without requiring native C++ Firebase runners.", table_cell_style)
        ],
        [
            Paragraph("<b>googleapis & google_sign_in</b>", table_cell_bold),
            Paragraph("^14.0.0 / ^6.2.1", table_cell_style),
            Paragraph("Google Drive API client allowing automated scheduled and manual encrypted SQLite database zip backups directly to owner's Google Drive.", table_cell_style)
        ]
    ]
    lib_table_2 = Table(lib_data_2, colWidths=[110, 55, 339])
    lib_table_2.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#0D9488")),
        ('PADDING', (0, 0), (-1, -1), 3),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, c_bg_light]),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(lib_table_2)
    story.append(Spacer(1, 6))

    # Page Break for Hardware, Printing & UI Libraries
    story.append(PageBreak())

    # Table 3: Hardware, Thermal Printing & Graphics
    story.append(Paragraph("C. Thermal Printing, Hardware & Graphics Libraries", h2_style))
    lib_data_3 = [
        [Paragraph("<b>Library / Dependency</b>", table_header_style), Paragraph("<b>Version</b>", table_header_style), Paragraph("<b>Specific Role & Use in SIMS Cafe</b>", table_header_style)],
        [
            Paragraph("<b>esc_pos_utils_plus & esc_pos_printer_plus</b>", table_cell_bold),
            Paragraph("^2.0.0 / ^0.1.1", table_cell_style),
            Paragraph("ESC/POS protocol byte generators: formats receipt layouts, bold text, column alignment, QR codes, paper cuts, and cash drawer kick pulses.", table_cell_style)
        ],
        [
            Paragraph("<b>flutter_usb_printer</b>", table_cell_bold),
            Paragraph("^0.1.0+1", table_cell_style),
            Paragraph("Direct USB communication for Android POS terminals communicating with thermal printers via USB OTG Vendor/Product IDs.", table_cell_style)
        ],
        [
            Paragraph("<b>SkiaSharp & SkiaSharp.HarfBuzz (.NET 8)</b>", table_cell_bold),
            Paragraph("2.88.8", table_cell_style),
            Paragraph("High-performance 2D graphics engine in <code>CafePrinter.exe</code>. Performs text shaping with HarfBuzz and rasterizes pixel-perfect 1-bit monochrome Arabic receipts using Cairo/Amiri fonts.", table_cell_style)
        ],
        [
            Paragraph("<b>image</b>", table_cell_bold),
            Paragraph("^4.2.0", table_cell_style),
            Paragraph("Bitmap image decoding, resizing, color space conversion, and dithering for logo printing on thermal receipts.", table_cell_style)
        ],
        [
            Paragraph("<b>pdf & flutter_pdfview</b>", table_cell_bold),
            Paragraph("^3.11.3 / ^1.3.2", table_cell_style),
            Paragraph("Vector PDF document generator and in-app interactive PDF viewer for sales reports, tax audits, and catering quotation sheets.", table_cell_style)
        ],
        [
            Paragraph("<b>excel</b>", table_cell_bold),
            Paragraph("^4.0.3", table_cell_style),
            Paragraph("Spreadsheet parsing and generation engine. Enables bulk Excel menu catalog imports and end-of-day sales data workbook exports.", table_cell_style)
        ],
        [
            Paragraph("<b>printing</b>", table_cell_bold),
            Paragraph("^5.14.2", table_cell_style),
            Paragraph("Standard OS document printing integration for standard A4/Letter invoice and report printouts.", table_cell_style)
        ]
    ]
    lib_table_3 = Table(lib_data_3, colWidths=[110, 55, 339])
    lib_table_3.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#0284C7")),
        ('PADDING', (0, 0), (-1, -1), 3),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, c_bg_light]),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(lib_table_3)
    story.append(Spacer(1, 6))

    # Table 4: Desktop Windowing, Media & Utilities
    story.append(Paragraph("D. Desktop OS Integration, Media & Utility Libraries", h2_style))
    lib_data_4 = [
        [Paragraph("<b>Library / Dependency</b>", table_header_style), Paragraph("<b>Version</b>", table_header_style), Paragraph("<b>Specific Role & Use in SIMS Cafe</b>", table_header_style)],
        [
            Paragraph("<b>window_manager</b>", table_cell_bold),
            Paragraph("^0.4.2", table_cell_style),
            Paragraph("Controls native Windows desktop window behavior: minimum dimensions (1024x768), kiosk fullscreen mode, and custom title bars.", table_cell_style)
        ],
        [
            Paragraph("<b>file_picker & desktop_drop</b>", table_cell_bold),
            Paragraph("^8.1.3 / ^0.4.4", table_cell_style),
            Paragraph("Native file picker dialogs and drag-and-drop support on Windows, allowing cashiers to drag Excel menu files directly into the app.", table_cell_style)
        ],
        [
            Paragraph("<b>camera & camera_windows</b>", table_cell_bold),
            Paragraph("^0.10.5 / ^0.2.1", table_cell_style),
            Paragraph("Accesses webcam on Windows and camera hardware on Android for barcode scanning and taking product photos.", table_cell_style)
        ],
        [
            Paragraph("<b>image_cropper & crop_your_image</b>", table_cell_bold),
            Paragraph("^11.0.0 / ^2.0.0", table_cell_style),
            Paragraph("In-app interactive image cropping and framing widget for menu item photos and company logo uploads.", table_cell_style)
        ],
        [
            Paragraph("<b>audioplayers</b>", table_cell_bold),
            Paragraph("^6.6.0", table_cell_style),
            Paragraph("Low-latency audio playback for auditory feedback (e.g. order placed sound, KOT alert chime, error alert).", table_cell_style)
        ],
        [
            Paragraph("<b>auto_updater & upgrader</b>", table_cell_bold),
            Paragraph("^0.1.7 / ^10.3.0", table_cell_style),
            Paragraph("Automated background update engines: Appcast XML feed updater for Windows EXE and in-app update prompt for Android APK.", table_cell_style)
        ],
        [
            Paragraph("<b>intl & flutter_dotenv</b>", table_cell_bold),
            Paragraph("^0.19.0 / ^5.2.1", table_cell_style),
            Paragraph("Internationalization, date/currency formatting (<code>DateFormat</code>, <code>NumberFormat</code>), and runtime <code>.env</code> file configuration loader.", table_cell_style)
        ],
        [
            Paragraph("<b>msix</b>", table_cell_bold),
            Paragraph("^3.16.6", table_cell_style),
            Paragraph("Windows MSIX package builder generating digitally signed Windows Store and enterprise deployment bundles.", table_cell_style)
        ]
    ]
    lib_table_4 = Table(lib_data_4, colWidths=[110, 55, 339])
    lib_table_4.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#4F46E5")),
        ('PADDING', (0, 0), (-1, -1), 3),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, c_bg_light]),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(lib_table_4)
    story.append(Spacer(1, 8))

    # Page Break for Functions & Features
    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # 3. FUNCTIONS & FEATURES SPECIFICATION
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("3. Functions & Features Catalog", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=c_secondary, spaceBefore=2, spaceAfter=5))

    story.append(Paragraph(
        "SIMS Cafe incorporates a full suite of restaurant and retail automation capabilities organized into functional modules:",
        body_style
    ))

    features_data = [
        [Paragraph("<b>Module</b>", table_header_style), Paragraph("<b>Function / Feature</b>", table_header_style), Paragraph("<b>Detailed Technical & Business Capabilities</b>", table_header_style)],
        [
            Paragraph("<b>1. Multi-Service POS & Ordering</b>", table_cell_bold),
            Paragraph("Dine-In, Takeout, Delivery, Drive-Thru, Catering", table_cell_style),
            Paragraph("• <b>Dine-In Table Grid:</b> Real-time floor plan with visual occupancy (Free, Occupied, Billed), split bill, and table merge.<br/>"
                      "• <b>Takeout / Fast Food:</b> Instant order entry with automated queue token generation.<br/>"
                      "• <b>Home Delivery:</b> Delivery boy assignment, customer address/contact tracking, and delivery surcharge.<br/>"
                      "• <b>Drive-Through:</b> Quick vehicle lane queueing with license plate recording.<br/>"
                      "• <b>Catering Bookings:</b> Event date/time, guest count, advance deposit logging, and balance tracking.", table_cell_style)
        ],
        [
            Paragraph("<b>2. Split Tender & Checkout</b>", table_cell_bold),
            Paragraph("Flexible Payment Matrix & Invoicing", table_cell_style),
            Paragraph("• <b>Split Payments:</b> Concurrently accept Cash, Card/Bank, Customer Credit, and Advance Deposit on a single invoice.<br/>"
                      "• <b>Taxation & Discounts:</b> Configurable VAT computation, item-level tax exemptions, and fixed or percentage discounts.<br/>"
                      "• <b>Change Calculator:</b> Dynamic change-due calculator with one-tap quick cash denomination buttons.<br/>"
                      "• <b>Temporary Bill Preview:</b> Print preliminary guest check receipts before final payment settlement.", table_cell_style)
        ],
        [
            Paragraph("<b>3. Kitchen Dispatch (Multi-KOT)</b>", table_cell_bold),
            Paragraph("Intelligent Station Routing", table_cell_style),
            Paragraph("• <b>Multi-Printer Matrix:</b> Splits an order across multiple kitchen stations (e.g. Barista, Hot Kitchen, Dessert station).<br/>"
                      "• <b>Modifier Notes:</b> Specific preparation notes per item (e.g. 'extra ice', 'no onion', 'well done').<br/>"
                      "• <b>Duplicate Safety:</b> Tracks printed items to prevent duplicate tickets on order updates.", table_cell_style)
        ],
        [
            Paragraph("<b>4. Menu & Inventory</b>", table_cell_bold),
            Paragraph("Product Catalog Management", table_cell_style),
            Paragraph("• <b>Multi-Size Pricing:</b> Assign size variations (Small, Medium, Large, Full, Half) with dynamic pricing.<br/>"
                      "• <b>Barcode Scanner:</b> Scan physical product barcodes for retail cafe snacks and beverages.<br/>"
                      "• <b>Profit Margin Tracking:</b> Records purchase cost vs selling price to compute live gross profit.<br/>"
                      "• <b>Excel Bulk Import/Export:</b> Add hundreds of menu items in seconds via formatted Excel spreadsheets.", table_cell_style)
        ],
        [
            Paragraph("<b>5. Customer Khata & Credit</b>", table_cell_bold),
            Paragraph("Customer Ledger & Debt Accounting", table_cell_style),
            Paragraph("• <b>Customer Directory:</b> Searchable customer CRM with contact numbers, addresses, and transaction history.<br/>"
                      "• <b>Credit Sale Tracking:</b> Bill orders directly to customer credit accounts.<br/>"
                      "• <b>Repayment Ledger:</b> Partial or full debt settlements with printed thermal payment vouchers.", table_cell_style)
        ],
        [
            Paragraph("<b>6. Expense & Cash Ledger</b>", table_cell_bold),
            Paragraph("Daily Overhead Reconciliation", table_cell_style),
            Paragraph("• <b>Daily Expense Logging:</b> Record vendor payouts, raw ingredient purchases, utility bills, and petty cash.<br/>"
                      "• <b>Cashier Shift Closing:</b> Automatically balances opening float + cash sales - cash expenses = drawer balance.", table_cell_style)
        ],
        [
            Paragraph("<b>7. Business Intelligence</b>", table_cell_bold),
            Paragraph("Reports & Export Analytics", table_cell_style),
            Paragraph("• <b>Interactive Dashboard:</b> Real-time charts for revenue growth, order volume, and hourly peak times.<br/>"
                      "• <b>Item-Wise Sales & Top Sellers:</b> Identifies top-performing dishes and slow-moving inventory.<br/>"
                      "• <b>Export Formats:</b> One-click export to PDF report summaries and structured Excel workbooks.", table_cell_style)
        ],
        [
            Paragraph("<b>8. Security & Recovery</b>", table_cell_bold),
            Paragraph("Role Guards & Crash Protection", table_cell_style),
            Paragraph("• <b>PIN-Protected Admin Functions:</b> Master PIN lock on Settings, Discount overrides, and Financial Reports.<br/>"
                      "• <b>Safe Mode Detector:</b> Dynamic fallback mode bypassing window/graphics crashes on damaged Windows setups.<br/>"
                      "• <b>Cloud Google Drive Backup:</b> Scheduled or manual zip archive database backup and restore.", table_cell_style)
        ]
    ]
    features_table = Table(features_data, colWidths=[105, 115, 284])
    features_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#0D9488")),
        ('PADDING', (0, 0), (-1, -1), 3),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, c_bg_light]),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(features_table)
    story.append(Spacer(1, 8))

    # Page Break for Requirements & Installation
    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # 4. SYSTEM REQUIREMENTS & INSTALLATION PREREQUISITES
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("4. System & Installation Requirements", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=c_secondary, spaceBefore=2, spaceAfter=5))

    story.append(Paragraph(
        "To deploy, run, or build SIMS Cafe, the following hardware, operating system, and software specifications are required:",
        body_style
    ))

    story.append(Paragraph("A. Hardware & Operational Specifications", h2_style))
    hw_reqs_data = [
        [Paragraph("<b>Component</b>", table_header_style), Paragraph("<b>Host PC / Main Cashier Terminal</b>", table_header_style), Paragraph("<b>Client Device (Waiter Tablet / Mobile)</b>", table_header_style)],
        [
            Paragraph("<b>Processor (CPU)</b>", table_cell_bold),
            Paragraph("Intel Core i3 / AMD Ryzen 3 (or higher, x64 architecture)", table_cell_style),
            Paragraph("Quad-core 1.8 GHz ARM processor (e.g. Snapdragon, MediaTek)", table_cell_style)
        ],
        [
            Paragraph("<b>Memory (RAM)</b>", table_cell_bold),
            Paragraph("Minimum 4 GB RAM (8 GB recommended for heavy traffic)", table_cell_style),
            Paragraph("Minimum 2 GB RAM (3 GB+ recommended for smooth UI)", table_cell_style)
        ],
        [
            Paragraph("<b>Disk Storage</b>", table_cell_bold),
            Paragraph("Minimum 500 MB free space (SSD recommended for SQLite I/O)", table_cell_style),
            Paragraph("Minimum 150 MB free internal flash storage", table_cell_style)
        ],
        [
            Paragraph("<b>Display Resolution</b>", table_cell_bold),
            Paragraph("1366x768 or 1920x1080 (Touchscreen monitor supported)", table_cell_style),
            Paragraph("7.0\" to 11.0\" Tablet display or 5.5\"+ Mobile Phone screen", table_cell_style)
        ],
        [
            Paragraph("<b>Network (Wi-Fi)</b>", table_cell_bold),
            Paragraph("Wi-Fi Router / Local LAN Switch (Same subnet, e.g. <code>192.168.1.x</code>)", table_cell_style),
            Paragraph("Connected to the same local Wi-Fi network as the Host PC", table_cell_style)
        ],
        [
            Paragraph("<b>Thermal Printer</b>", table_cell_bold),
            Paragraph("80mm or 58mm ESC/POS Thermal Receipt & KOT Printer (USB, LAN, or COM)", table_cell_style),
            Paragraph("Network TCP/IP Thermal Printer or USB OTG Thermal Printer", table_cell_style)
        ]
    ]
    hw_table = Table(hw_reqs_data, colWidths=[110, 197, 197])
    hw_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#1E293B")),
        ('PADDING', (0, 0), (-1, -1), 3),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, c_bg_light]),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(hw_table)
    story.append(Spacer(1, 6))

    story.append(Paragraph("B. Operating System & Runtime Prerequisites", h2_style))
    story.append(Paragraph("• <b>Windows Desktop:</b> Windows 10 (Build 19041+) or Windows 11 (64-bit). Requires <i>Visual C++ 2015-2022 Redistributable</i>.", bullet_style))
    story.append(Paragraph("• <b>Android Environment:</b> Android 6.0 (API Level 23) up to Android 15. Requires Camera and Local Storage permissions.", bullet_style))
    story.append(Paragraph("• <b>Local Network Rules:</b> Windows Firewall must allow inbound traffic on TCP Port <b>8642</b> (LAN sync) and Port <b>9100</b> (Raw printer socket).", bullet_style))

    story.append(Paragraph("C. Developer & Build Toolchain Requirements", h2_style))
    story.append(Paragraph("If compiling the project from source code, the following tools must be installed on the build workstation:", body_style))
    
    dev_reqs_data = [
        [Paragraph("<b>Development Tool</b>", table_header_style), Paragraph("<b>Required Version</b>", table_header_style), Paragraph("<b>Purpose in Build Process</b>", table_header_style)],
        [Paragraph("<b>Flutter SDK</b>", table_cell_bold), Paragraph("v3.29.0 or higher (Channel stable)", table_cell_style), Paragraph("Compiles Flutter Dart application for Windows x64 and Android APK.", table_cell_style)],
        [Paragraph("<b>.NET SDK</b>", table_cell_bold), Paragraph(".NET 8.0 SDK (x64)", table_cell_style), Paragraph("Compiles <code>CafePrinter.csproj</code> into self-contained single-file <code>CafePrinter.exe</code>.", table_cell_style)],
        [Paragraph("<b>Inno Setup</b>", table_cell_bold), Paragraph("Inno Setup 6.x (ISCC.exe)", table_cell_style), Paragraph("Packages Flutter binaries, C# printing microservice, assets, and icons into setup wizard.", table_cell_style)],
        [Paragraph("<b>Visual Studio</b>", table_cell_bold), Paragraph("VS 2022 (Desktop C++ workload)", table_cell_style), Paragraph("Provides MSVC compiler and CMake toolchain for Flutter Windows desktop runner.", table_cell_style)],
        [Paragraph("<b>Android SDK / Java</b>", table_cell_bold), Paragraph("JDK 17 + Android SDK API 34", table_cell_style), Paragraph("Compiles and signs release APK packages with Gradle 8+.", table_cell_style)],
    ]
    dev_table = Table(dev_reqs_data, colWidths=[110, 130, 264])
    dev_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#0284C7")),
        ('PADDING', (0, 0), (-1, -1), 3),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, c_bg_light]),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(dev_table)
    story.append(Spacer(1, 6))

    story.append(Paragraph("D. Step-by-Step Installation Guides", h2_style))
    story.append(Paragraph("<b>1. Installing on Windows Desktop (End-User):</b><br/>"
                           "• Step 1: Run <code>SimsCafe_Setup_v2.0.exe</code>.<br/>"
                           "• Step 2: Follow the setup wizard to install into <code>C:\\Program Files\\SIMS CAFE</code>.<br/>"
                           "• Step 3: Launch SIMS CAFE from Desktop shortcut. The app automatically creates its databases in <code>%APPDATA%/com.example.cafeapp/databases/</code>.<br/>"
                           "• Step 4: Open <i>Printer Settings</i> to select your receipt printer and set Host Mode to <b>Server</b>.", body_style))
    story.append(Paragraph("<b>2. Installing on Android Tablets/Mobiles (End-User):</b><br/>"
                           "• Step 1: Transfer <code>app-release.apk</code> to the device via USB, WhatsApp, or local download link.<br/>"
                           "• Step 2: Enable 'Install from Unknown Sources' and tap the APK to install.<br/>"
                           "• Step 3: Connect the tablet to the cafe's Wi-Fi network. Open SIMS CAFE -> <i>Device Management</i>.<br/>"
                           "• Step 4: Tap <b>Auto-Discover Host</b> or enter Host IP (e.g. <code>192.168.1.100:8642</code>) to sync all menu and table data.", body_style))
    story.append(Spacer(1, 8))

    # Page Break for Database Schemas
    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # 5. DATABASE ARCHITECTURE & SQLITE SCHEMAS
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("5. Local Database Architecture & SQLite Schemas", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=c_secondary, spaceBefore=2, spaceAfter=5))
    
    schema_intro = (
        "The system isolates its storage into <b>six dedicated SQLite databases</b> located in the persistent OS application directory. "
        "Each database operates with Write-Ahead Logging (WAL) and explicit version migration scripts."
    )
    story.append(Paragraph(schema_intro, body_style))

    story.append(Paragraph("A. cafe_orders.db — Orders & Items Schema", h2_style))
    orders_table_data = [
        [Paragraph("<b>Field Name</b>", table_header_style), Paragraph("<b>Data Type</b>", table_header_style), Paragraph("<b>Constraints & Functional Role</b>", table_header_style)],
        [Paragraph("<code>id</code>", table_cell_bold), Paragraph("INTEGER", table_cell_style), Paragraph("Primary Key, AUTOINCREMENT", table_cell_style)],
        [Paragraph("<code>staff_order_number</code>", table_cell_bold), Paragraph("INTEGER", table_cell_style), Paragraph("Staff device local order counter (prevents race conditions)", table_cell_style)],
        [Paragraph("<code>main_order_number</code>", table_cell_bold), Paragraph("INTEGER", table_cell_style), Paragraph("Synchronized master order sequence assigned by server", table_cell_style)],
        [Paragraph("<code>staff_device_id</code>", table_cell_bold), Paragraph("TEXT", table_cell_style), Paragraph("Originating device identifier / UUID", table_cell_style)],
        [Paragraph("<code>service_type</code>", table_cell_bold), Paragraph("TEXT", table_cell_style), Paragraph("Dining (Table X), Takeout, Delivery, Drive Through, Catering", table_cell_style)],
        [Paragraph("<code>subtotal, tax, discount</code>", table_cell_bold), Paragraph("REAL", table_cell_style), Paragraph("Financial components calculated before final net total", table_cell_style)],
        [Paragraph("<code>total</code>", table_cell_bold), Paragraph("REAL", table_cell_style), Paragraph("Net payable amount after applying tax and discounts", table_cell_style)],
        [Paragraph("<code>payment_method</code>", table_cell_bold), Paragraph("TEXT", table_cell_style), Paragraph("<code>cash</code>, <code>bank</code>, <code>credit</code>, <code>deposit</code>, <code>split</code>", table_cell_style)],
        [Paragraph("<code>cash_amount, bank_amount</code>", table_cell_bold), Paragraph("REAL", table_cell_style), Paragraph("Individual split payment contributions", table_cell_style)],
        [Paragraph("<code>customer_id, customer_name</code>", table_cell_bold), Paragraph("TEXT", table_cell_style), Paragraph("Linked customer record for Khata / credit billing", table_cell_style)],
        [Paragraph("<code>delivery_boy, delivery_address</code>", table_cell_bold), Paragraph("TEXT", table_cell_style), Paragraph("Delivery dispatch information and rider assignment", table_cell_style)],
        [Paragraph("<code>event_date, event_guest_count</code>", table_cell_bold), Paragraph("TEXT / INT", table_cell_style), Paragraph("Catering specific booking metadata", table_cell_style)],
        [Paragraph("<code>deposit_amount</code>", table_cell_bold), Paragraph("REAL", table_cell_style), Paragraph("Advance deposit paid for catering bookings", table_cell_style)],
        [Paragraph("<code>token_number</code>", table_cell_bold), Paragraph("TEXT", table_cell_style), Paragraph("Customer queue token printed for takeout service", table_cell_style)],
        [Paragraph("<code>status</code>", table_cell_bold), Paragraph("TEXT", table_cell_style), Paragraph("<code>pending</code>, <code>completed</code>, <code>cancelled</code>", table_cell_style)],
        [Paragraph("<code>created_at, updated_at</code>", table_cell_bold), Paragraph("TEXT", table_cell_style), Paragraph("ISO 8601 timestamps for Last-Write-Wins conflict resolution", table_cell_style)],
        [Paragraph("<code>is_synced, is_deleted</code>", table_cell_bold), Paragraph("INTEGER", table_cell_style), Paragraph("LAN sync status flag (0/1) and soft-deletion tombstone", table_cell_style)],
    ]
    orders_table = Table(orders_table_data, colWidths=[115, 75, 314])
    orders_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#1E293B")),
        ('PADDING', (0, 0), (-1, -1), 2.5),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, c_bg_light]),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    story.append(orders_table)
    story.append(Spacer(1, 6))

    story.append(Paragraph("B. order_items (Child Table with CASCADE Delete)", h2_style))
    order_items_data = [
        [Paragraph("<b>Field Name</b>", table_header_style), Paragraph("<b>Data Type</b>", table_header_style), Paragraph("<b>Description & Relationship</b>", table_header_style)],
        [Paragraph("<code>id</code>", table_cell_bold), Paragraph("INTEGER", table_cell_style), Paragraph("Primary Key, AUTOINCREMENT", table_cell_style)],
        [Paragraph("<code>order_id</code>", table_cell_bold), Paragraph("INTEGER", table_cell_style), Paragraph("Foreign Key -> <code>orders(id) ON DELETE CASCADE</code>", table_cell_style)],
        [Paragraph("<code>menu_item_id</code>", table_cell_bold), Paragraph("INTEGER", table_cell_style), Paragraph("Referenced menu product ID", table_cell_style)],
        [Paragraph("<code>name, price, quantity</code>", table_cell_bold), Paragraph("TEXT/REAL/INT", table_cell_style), Paragraph("Snapshot of item details at time of order creation", table_cell_style)],
        [Paragraph("<code>kitchen_note</code>", table_cell_bold), Paragraph("TEXT", table_cell_style), Paragraph("Custom cooking instructions (e.g. 'extra spicy', 'no sugar')", table_cell_style)],
        [Paragraph("<code>tax_exempt, purchase_price</code>", table_cell_bold), Paragraph("INT / REAL", table_cell_style), Paragraph("Tax zero-rating flag and purchase cost for gross profit reports", table_cell_style)],
    ]
    items_table = Table(order_items_data, colWidths=[115, 75, 314])
    items_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#0D9488")),
        ('PADDING', (0, 0), (-1, -1), 2.5),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, c_bg_light]),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    story.append(items_table)
    story.append(Spacer(1, 6))

    story.append(Paragraph("C. Supporting Databases Overview", h2_style))
    other_dbs_data = [
        [Paragraph("<b>Database File</b>", table_header_style), Paragraph("<b>Primary Table</b>", table_header_style), Paragraph("<b>Key Columns & Purpose</b>", table_header_style)],
        [
            Paragraph("<code>cafe_menu.db</code>", table_cell_bold),
            Paragraph("<code>menu_items</code>", table_cell_style),
            Paragraph("<code>id, name, price, imageUrl, category, isAvailable, isDeleted, lastUpdated, taxExempt, isPerPlate, purchasePrice, barcode, sizes (JSON)</code>.", table_cell_style)
        ],
        [
            Paragraph("<code>cafe_persons.db</code>", table_cell_bold),
            Paragraph("<code>persons</code>", table_cell_style),
            Paragraph("<code>id, name, phoneNumber, place, dateVisited, credit, updated_at, is_deleted</code>. Stores customer CRM profile and cumulative credit debt.", table_cell_style)
        ],
        [
            Paragraph("<code>credit_transactions.db</code>", table_cell_bold),
            Paragraph("<code>credit_transactions</code>", table_cell_style),
            Paragraph("<code>id, customerId, customerName, orderNumber, amount, createdAt, serviceType, isCompleted, updated_at</code>. Double-entry audit ledger for credit sales & repayments.", table_cell_style)
        ],
        [
            Paragraph("<code>cafe_expenses.db</code>", table_cell_bold),
            Paragraph("<code>expenses</code> & <code>expense_items</code>", table_cell_style),
            Paragraph("<code>id, date, cashier, accountType, grandTotal, createdAt</code> + items: <code>slNo, account, narration, amount, remarks</code>. Tracks overheads and vendor bills.", table_cell_style)
        ],
        [
            Paragraph("<code>cafe_delivery_boys_store.db</code>", table_cell_bold),
            Paragraph("<code>delivery_boys</code>", table_cell_style),
            Paragraph("<code>id, name, phoneNumber, updated_at, is_deleted</code>. Roster of delivery drivers assigned to takeout deliveries.", table_cell_style)
        ]
    ]
    other_dbs_table = Table(other_dbs_data, colWidths=[115, 95, 294])
    other_dbs_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#475569")),
        ('PADDING', (0, 0), (-1, -1), 3),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, c_bg_light]),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(other_dbs_table)
    story.append(Spacer(1, 8))

    # Page Break for Networking & Printing
    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # 6. NETWORKING, REST APIS & HARDWARE PRINTING
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("6. Networking, APIs & Hardware Integration", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=c_secondary, spaceBefore=2, spaceAfter=5))

    story.append(Paragraph("A. Embedded Host REST API Endpoints (Shelf Server :8642)", h2_style))
    endpoints_data = [
        [Paragraph("<b>Endpoint</b>", table_header_style), Paragraph("<b>Method</b>", table_header_style), Paragraph("<b>Payload & Description</b>", table_header_style)],
        [
            Paragraph("<code>/api/ping</code>", table_cell_bold),
            Paragraph("GET", table_cell_style),
            Paragraph("Heartbeat & server discovery. Returns server name, IP, and timestamp.", table_cell_style)
        ],
        [
            Paragraph("<code>/api/sync/full</code>", table_cell_bold),
            Paragraph("GET", table_cell_style),
            Paragraph("Transmits complete snapshot of Orders, Menu, Customers, and Tables for new node onboarding.", table_cell_style)
        ],
        [
            Paragraph("<code>/api/sync/incremental</code>", table_cell_bold),
            Paragraph("POST", table_cell_style),
            Paragraph("Differential sync: Client sends <code>{since: timestamp}</code>, server returns only updated records.", table_cell_style)
        ],
        [
            Paragraph("<code>/api/sync/push</code>", table_cell_bold),
            Paragraph("POST", table_cell_style),
            Paragraph("Client pushes newly created orders and customer edits directly to host database.", table_cell_style)
        ],
        [
            Paragraph("<code>/ws</code>", table_cell_bold),
            Paragraph("WS", table_cell_style),
            Paragraph("Bi-directional real-time WebSocket channel broadcasting <code>ORDER_CREATED</code>, <code>TABLE_OCCUPIED</code>, etc.", table_cell_style)
        ]
    ]
    endpoints_table = Table(endpoints_data, colWidths=[105, 45, 354])
    endpoints_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#0F172A")),
        ('PADDING', (0, 0), (-1, -1), 3),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, c_bg_light]),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(endpoints_table)
    story.append(Spacer(1, 6))

    story.append(Paragraph("B. Thermal Printing & Hardware Control", h2_style))
    printer_data = [
        [Paragraph("<b>Printer Mode</b>", table_header_style), Paragraph("<b>Target Environment</b>", table_header_style), Paragraph("<b>Implementation & Capabilities</b>", table_header_style)],
        [
            Paragraph("<b>Windows Spooler (RAW)</b>", table_cell_bold),
            Paragraph("Windows Desktop (`cafeapp.exe`)", table_cell_style),
            Paragraph("Delegates to <code>CafePrinter.exe</code> (.NET 8). Uses Win32 <code>winspool.drv</code> APIs (<code>OpenPrinter</code>, <code>StartDocPrinter</code>, <code>WritePrinter</code>) to send raw ESC/POS binary directly to USB/LAN printers.", table_cell_style)
        ],
        [
            Paragraph("<b>Network TCP Socket</b>", table_cell_bold),
            Paragraph("Android Tablet / Windows", table_cell_style),
            Paragraph("Direct raw TCP socket connection on Port <b>9100</b>. Connects directly to Ethernet/Wi-Fi thermal printers with 3-second timeout protection.", table_cell_style)
        ],
        [
            Paragraph("<b>Android USB Direct</b>", table_cell_bold),
            Paragraph("Android POS Hardware", table_cell_style),
            Paragraph("Uses <code>flutter_usb_printer</code> to communicate directly with thermal printers via USB OTG Vendor ID / Product ID endpoints.", table_cell_style)
        ],
        [
            Paragraph("<b>Arabic RTL Rasterizer</b>", table_cell_bold),
            Paragraph("Multilingual Receipts", table_cell_style),
            Paragraph("Employs <b>SkiaSharp</b> bitmap rasterization with Amiri and Cairo fonts. Generates pixel-perfect 1-bit monochrome bitmaps for ESC/POS printers lacking Arabic hardware code pages.", table_cell_style)
        ]
    ]
    printer_table = Table(printer_data, colWidths=[110, 110, 284])
    printer_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#1E293B")),
        ('PADDING', (0, 0), (-1, -1), 3),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, c_bg_light]),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(printer_table)
    story.append(Spacer(1, 8))

    # ══════════════════════════════════════════════════════════════════════════
    # 7. BUILD, PACKAGING & COMPILATION COMMANDS
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("7. Build & Compilation Guide (Windows EXE & Android APK)", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=c_secondary, spaceBefore=2, spaceAfter=5))

    story.append(Paragraph("A. Automated Windows Build Workflow", h2_style))
    story.append(Paragraph(
        "Windows deployment is automated via <code>cafeapp/build_installer.bat</code>:<br/>"
        "1. <b>Publish C# Printing Service:</b><br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;<code>cd CafePrinter</code><br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;<code>dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o publish\\</code><br/>"
        "2. <b>Build Flutter Windows Release:</b><br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;<code>cd ..\\cafeapp</code><br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;<code>flutter clean && flutter build windows --release</code><br/>"
        "3. <b>Copy Companion Executable:</b><br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;Copy <code>CafePrinter.exe</code> into <code>build\\windows\\x64\\runner\\Release\\</code>.<br/>"
        "4. <b>Compile Inno Setup Installer:</b><br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;<code>\"C:\\Program Files (x86)\\Inno Setup 6\\ISCC.exe\" sims_cafe_installer.iss</code><br/>"
        "&nbsp;&nbsp;&nbsp;&nbsp;Output: <code>installer_output/SimsCafe_Setup_v2.0.exe</code>",
        body_style
    ))

    story.append(Paragraph("B. Android Release APK Compilation", h2_style))
    story.append(Paragraph(
        "1. <b>Fetch Dependencies:</b> <code>flutter pub get</code><br/>"
        "2. <b>Build Release APK:</b> <code>flutter build apk --release --split-per-abi</code><br/>"
        "3. <b>Output File:</b> <code>build/app/outputs/flutter-apk/app-release.apk</code>",
        body_style
    ))
    story.append(Spacer(1, 8))

    # Page Break for Teaching & Viva Guide
    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # 8. TEACHING, PRESENTATION & VIVA GUIDE
    # ══════════════════════════════════════════════════════════════════════════
    story.append(Paragraph("8. Presentation & Teaching Manual (Demo Script & Viva Q&A)", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=c_secondary, spaceBefore=2, spaceAfter=5))

    story.append(Paragraph("A. 2-Minute Elevator Pitch", h2_style))
    pitch_box = [
        [
            Paragraph(
                "\"SIMS Cafe is an enterprise-grade, offline-first Restaurant POS and ERP ecosystem built with Flutter and .NET. "
                "Unlike traditional cloud POS systems that halt when internet connections drop, SIMS Cafe runs 100% locally with high-performance "
                "SQLite databases, while maintaining real-time sub-second sync across all cashier terminals and waiter tablets over local Wi-Fi. "
                "It handles end-to-end cafe operations: dynamic table management, multi-station kitchen ticket routing, split payments, "
                "customer credit tracking, VAT accounting, expense ledgers, and automated cloud backups.\"",
                body_style
            )
        ]
    ]
    pitch_table = Table(pitch_box, colWidths=[504])
    pitch_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), c_callout_bg),
        ('PADDING', (0, 0), (-1, -1), 7),
        ('BOX', (0, 0), (-1, -1), 1, c_teal),
    ]))
    story.append(pitch_table)
    story.append(Spacer(1, 6))

    story.append(Paragraph("B. Step-by-Step Live Demonstration Script", h2_style))
    demo_steps = [
        Paragraph("1. <b>Host Launch & Discovery:</b> Launch the Windows desktop app. Show that the embedded Shelf server starts immediately on port 8642. Connect an Android tablet or second window to demonstrate auto-discovery.", bullet_style),
        Paragraph("2. <b>Dining Table Order:</b> Open Table Grid. Select Table 4. Add 2 Cappuccinos + 1 Burger with 'extra sauce'. Show that Table 4 instantly turns orange (occupied) on all other connected devices in real time via WebSockets.", bullet_style),
        Paragraph("3. <b>Multi-KOT Kitchen Routing:</b> Tap 'Send to Kitchen'. Explain how the system splits the items—sending the burger to the kitchen printer and the coffee to the barista printer.", bullet_style),
        Paragraph("4. <b>Tender & Split Checkout:</b> Go to checkout. Split payment ($10 cash + $15 card) and demonstrate VAT/discount calculation. Complete the order to trigger the final ESC/POS customer receipt with QR/Barcode.", bullet_style),
        Paragraph("5. <b>Customer Credit (Khata):</b> Demonstrate selecting a registered customer, charging an order to credit, and opening Customer Management to show the updated debt ledger and repayment settlement.", bullet_style),
        Paragraph("6. <b>Day-End Analytics & Export:</b> Open Reports screen to show live revenue charts, tax breakdown, and item sales. Export a clean PDF/Excel report with one click.", bullet_style),
    ]
    for step in demo_steps:
        story.append(step)
    story.append(Spacer(1, 6))

    story.append(Paragraph("C. Technical Viva / Defense Questions & Model Answers", h2_style))
    viva_qa = [
        [
            Paragraph("<b>Question 1: Why did you choose SQLite over a single centralized cloud database (like MongoDB or MySQL)?</b>", table_cell_bold),
        ],
        [
            Paragraph("<b>Answer:</b> Hospitality businesses cannot tolerate downtime. If the internet drops during peak dining hours, a cloud-dependent POS freezes, causing severe revenue loss. SQLite provides zero-latency, ACID-compliant local storage on every device. Our embedded Shelf LAN sync layer bridges devices locally, offering cloud-like synchronization without internet dependency.", table_cell_style)
        ],
        [
            Paragraph("<b>Question 2: How do you prevent duplicate order numbers when multiple waiter tablets take orders simultaneously offline?</b>", table_cell_bold),
        ],
        [
            Paragraph("<b>Answer:</b> We implemented a <i>Dual Numbering Architecture</i>. Each staff device maintains its own local counter (<code>staff_order_number</code>). When the order reaches the host or is completed, the master terminal assigns the official synchronized <code>main_order_number</code>. This completely eliminates race conditions.", table_cell_style)
        ],
        [
            Paragraph("<b>Question 3: Why is there a separate C# project (CafePrinter.exe) instead of using Flutter printing plugins directly?</b>", table_cell_bold),
        ],
        [
            Paragraph("<b>Answer:</b> Flutter desktop printing plugins often struggle with raw ESC/POS byte streaming, device status interrogation (detecting paper-out/offline queues), and Arabic typography shaping. CafePrinter.exe leverages Win32 <code>winspool.drv</code> and SkiaSharp to provide native spooler access, instant offline detection, and pixel-perfect Arabic rendering.", table_cell_style)
        ],
        [
            Paragraph("<b>Question 4: How does the system handle database migrations when releasing app updates on Windows?</b>", table_cell_bold),
        ],
        [
            Paragraph("<b>Answer:</b> In <code>DatabaseHelper.dart</code>, we store databases in a stable OS-managed directory (<code>AppData/Roaming/com.example.cafeapp/databases/</code>). When updating, the app auto-detects legacy database files, copies WAL/SHM journal files safely, and executes SQLite <code>onUpgrade</code> scripts incrementally.", table_cell_style)
        ]
    ]
    viva_table = Table(viva_qa, colWidths=[504])
    viva_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#F1F5F9")),
        ('BACKGROUND', (0, 2), (-1, 2), colors.HexColor("#F1F5F9")),
        ('BACKGROUND', (0, 4), (-1, 4), colors.HexColor("#F1F5F9")),
        ('BACKGROUND', (0, 6), (-1, 6), colors.HexColor("#F1F5F9")),
        ('PADDING', (0, 0), (-1, -1), 3),
        ('GRID', (0, 0), (-1, -1), 0.5, c_border),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(viva_table)
    story.append(Spacer(1, 8))

    # Build Document
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Successfully generated {filename}")

if __name__ == '__main__':
    build_pdf()
