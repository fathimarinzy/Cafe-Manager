using System.Collections.Generic;

namespace CafePrinter;

public record PrintItem(
    string Id,
    string Name,
    double Price,
    int Quantity,
    string KitchenNote
);

// Id is long, not int: Dart integers are 64-bit and menu item ids can exceed
// Int32.MaxValue (timestamp-derived ids do). A 32-bit Id made System.Text.Json
// throw "could not be converted to OriginalItem", which surfaced in the app as
// a bogus "KOT printer not available" dialog on editing an order.
// Name is needed because a fully-cancelled item is no longer present in Items,
// so the renderer has nothing else to label it with and fell back to printing
// the raw id ("#1735689600000") on the kitchen ticket. Defaulted so payloads
// written before this field existed still parse.
public record OriginalItem(
    long Id,
    int Quantity,
    string Name = ""
);

public record ReceiptPrintData(
    string PrinterName,
    bool OpenDrawer,
    string BusinessName,
    string SecondBusinessName,
    string BusinessAddress,
    string BusinessPhone,
    string LogoPath,
    string ServiceType,
    string OrderNumber,
    string PersonName,
    double Subtotal,
    double Tax,
    double TaxRate,
    double Discount,
    double Total,
    double DepositAmount,
    double DeliveryCharge,
    string Title,
    List<PrintItem> Items,
    // Decimal places for money on the receipt, mirroring the app's
    // Settings > Currency / Number Format option. Defaulted so payloads written
    // before this field existed still parse, and because 3 is what the renderer
    // hard-coded previously.
    int DecimalPlaces = 3
);

public record KotPrintData(
    string PrinterName,
    string ServiceType,
    string OrderNumber,
    bool IsEdited,
    List<PrintItem> Items,
    List<OriginalItem>? OriginalItems
);
