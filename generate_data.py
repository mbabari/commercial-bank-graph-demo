#!/usr/bin/env python3
"""Generate synthetic CSV data for the Commercial Bank Graph Neo4j demo."""

import csv
import random
import os
from datetime import date, timedelta

random.seed(42)

OUT = os.path.join(os.path.dirname(__file__), "data")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------------------
# Reference data
# ---------------------------------------------------------------------------

PROVINCES = [
    "Gauteng", "Western Cape", "KwaZulu-Natal", "Eastern Cape",
    "Free State", "Mpumalanga", "Limpopo", "North West", "Northern Cape"
]

SEGMENTS = ["SME", "Mid-Corp", "Large Corp"]

SA_BUSINESS_PREFIXES = [
    "Azania", "Protea", "Springbok", "Table Mountain", "Karoo",
    "Highveld", "Bushveld", "Drakensberg", "Waterberg", "Lowveld",
    "Golden", "Cape", "Reef", "Valley", "Sunrise", "Ubuntu", "Thaba",
    "Berea", "Sandton", "Rosebank", "Midrand", "Centurion", "Menlyn",
    "Fourways", "Bryanston", "Rivonia", "Bedfordview", "Kempton",
    "Umhlanga", "Ballito", "Stellenbosch", "Paarl", "Franschhoek",
    "Knysna", "Hermanus", "Mossel Bay", "Port Elizabeth", "East London",
    "Bloemfontein", "Polokwane", "Nelspruit", "Rustenburg", "Mahikeng",
    "Kimberley", "Upington"
]

SA_BUSINESS_SUFFIXES = [
    "Trading", "Logistics", "Construction", "Engineering", "Mining",
    "Agriculture", "Manufacturing", "Properties", "Holdings", "Investments",
    "Solutions", "Services", "Enterprises", "Technologies", "Transport",
    "Energy", "Foods", "Retail", "Chemicals", "Steel", "Textiles",
    "Pharma", "Motors", "Freight", "Exports", "Imports", "Group",
    "Capital", "Finance", "Consulting"
]

INDUSTRIES_DATA = [
    ("1110", "Growing of cereals", "Agriculture"),
    ("1512", "Processing of meat", "Manufacturing"),
    ("2310", "Manufacture of coke oven products", "Manufacturing"),
    ("2520", "Manufacture of plastics", "Manufacturing"),
    ("2710", "Manufacture of basic iron and steel", "Manufacturing"),
    ("4100", "Construction of buildings", "Construction"),
    ("4520", "Maintenance of motor vehicles", "Automotive"),
    ("4711", "Retail sale in non-specialised stores", "Retail"),
    ("4923", "Freight transport by road", "Transport"),
    ("5510", "Hotels and accommodation", "Hospitality"),
    ("5610", "Restaurants and food service", "Hospitality"),
    ("6110", "Wired telecommunications", "Telecoms"),
    ("6201", "Computer programming", "Technology"),
    ("6411", "Central banking", "Financial Services"),
    ("6420", "Activities of holding companies", "Financial Services"),
    ("6810", "Real estate with own property", "Real Estate"),
    ("7111", "Architectural activities", "Professional Services"),
    ("7120", "Technical testing and analysis", "Professional Services"),
    ("8610", "Hospital activities", "Healthcare"),
    ("9700", "Mining of metal ores", "Mining"),
]

PRODUCTS_DATA = [
    ("P001", "Business Overdraft", "lend", 250.00),
    ("P002", "Term Loan", "lend", 0.00),
    ("P003", "Asset Finance", "lend", 150.00),
    ("P004", "Trade Finance Facility", "lend", 500.00),
    ("P005", "Business Cheque Account", "transact", 199.00),
    ("P006", "Business Savings Account", "transact", 0.00),
    ("P007", "Merchant POS Terminal", "transact", 350.00),
    ("P008", "Commercial Pay", "transact", 75.00),
    ("P009", "Fixed Deposit", "invest", 0.00),
    ("P010", "Money Market Account", "invest", 0.00),
    ("P011", "Unit Trust Portfolio", "invest", 100.00),
    ("P012", "Commercial Property Insurance", "insure", 450.00),
    ("P013", "Business Liability Insurance", "insure", 320.00),
    ("P014", "Fleet Insurance", "insure", 600.00),
]

EFT_REFERENCES = [
    "SALARY", "SUPPLIER PMT", "INVOICE", "RENT", "RATES",
    "FUEL", "STOCK", "MAINTENANCE", "CONSULTING FEE", "DELIVERY",
    "RAW MATERIALS", "SUBSCRIPTION", "INSURANCE PREMIUM", "UTILITIES",
    "TAX PAYMENT", "LOAN REPAYMENT", "COMMISSION", "FREIGHT CHARGE",
]

SWIFT_CURRENCIES = ["USD", "EUR", "GBP", "ZAR"]

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

def rand_date(start: date, end: date) -> date:
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))

def rand_zar(low: float, high: float) -> float:
    return round(random.uniform(low, high), 2)

def unique_name(used: set) -> str:
    for _ in range(500):
        name = f"{random.choice(SA_BUSINESS_PREFIXES)} {random.choice(SA_BUSINESS_SUFFIXES)}"
        if name not in used:
            used.add(name)
            return name
    raise ValueError("Could not generate unique name")


# ---------------------------------------------------------------------------
# Name-variant helpers for entity resolution (planted near-duplicates)
# ---------------------------------------------------------------------------

SUFFIX_VARIANTS = {
    "Engineering": ["Eng", "Eng.", "Engineers"],
    "Manufacturing": ["Mfg", "Manufacturers", "Mfg."],
    "Logistics": ["Logistics Solutions", "Log Services"],
    "Construction": ["Const", "Builders"],
    "Holdings": ["Holdings Group", "Hldgs"],
    "Investments": ["Invest", "Investment Co"],
    "Solutions": ["Solutions Group", "Sol"],
    "Services": ["Svcs", "Service Co"],
    "Technologies": ["Tech", "Technology"],
    "Properties": ["Property Group", "Props"],
    "Transport": ["Trans", "Transport Co"],
    "Trading": ["Trade", "Traders"],
    "Chemicals": ["Chem", "Chemical Co"],
    "Consulting": ["Consultants", "Consult"],
    "Motors": ["Motor Co", "Mtrs"],
    "Freight": ["Freight Services", "Freight Co"],
    "Energy": ["Energy Solutions", "Power"],
    "Foods": ["Food Services", "Food Co"],
    "Retail": ["Retail Group", "Retailers"],
    "Steel": ["Steel Works", "Steels"],
    "Textiles": ["Textile Co", "Fabrics"],
    "Pharma": ["Pharmaceuticals", "Pharma Co"],
    "Mining": ["Mines", "Mining Co"],
    "Agriculture": ["Agri", "Agri Co"],
    "Capital": ["Capital Group", "Cap"],
    "Finance": ["Financial Services", "Fin"],
    "Exports": ["Exporters"],
    "Imports": ["Importers"],
    "Group": ["Holdings", "Group Holdings"],
    "Enterprises": ["Enterprise", "Ent"],
}

PREFIX_VARIANTS = {
    "Port Elizabeth": ["PE", "Pt Elizabeth"],
    "East London": ["EL", "E London"],
    "Mossel Bay": ["M Bay"],
    "Bloemfontein": ["Bloem"],
}

# Legal-name style variants only — keeps Jaro–Winkler high so composite confidence can
# exceed 0.70 even when trading Jaccard is diluted by random transactions.
HIGH_CONF_NAME_SUFFIXES = [
    lambda s: f"{s} (Pty) Ltd",
    lambda s: f"{s} Pty Ltd",
    lambda s: f"{s} SA",
    lambda s: f"{s} (Pty)Ltd",
]


def create_high_confidence_name_variant(original_name: str, variant_index: int) -> str:
    fn = HIGH_CONF_NAME_SUFFIXES[(variant_index - 1) % len(HIGH_CONF_NAME_SUFFIXES)]
    return fn(original_name)


def create_name_variant(original_name: str) -> str:
    """Create a plausible fuzzy variant of a business name."""
    prefix_match = None
    suffix = None
    for full_prefix in PREFIX_VARIANTS:
        if original_name.startswith(full_prefix + " "):
            prefix_match = full_prefix
            suffix = original_name[len(full_prefix) + 1:]
            break

    if prefix_match is None:
        parts = original_name.split(" ", 1)
        prefix_match = parts[0]
        suffix = parts[1] if len(parts) > 1 else ""

    strategies = []
    if suffix in SUFFIX_VARIANTS:
        strategies.append("suffix_variant")
    if prefix_match in PREFIX_VARIANTS:
        strategies.append("prefix_variant")
    strategies.append("add_pty_ltd")

    strategy = random.choice(strategies)

    if strategy == "suffix_variant":
        return f"{prefix_match} {random.choice(SUFFIX_VARIANTS[suffix])}"
    elif strategy == "prefix_variant":
        return f"{random.choice(PREFIX_VARIANTS[prefix_match])} {suffix}"
    else:
        tag = random.choice(["Pty Ltd", "(Pty) Ltd", "SA"])
        return f"{original_name} {tag}"

# ---------------------------------------------------------------------------
# 1. Industries
# ---------------------------------------------------------------------------

with open(os.path.join(OUT, "industries.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["sicCode", "name", "sector"])
    for row in INDUSTRIES_DATA:
        w.writerow(row)

print(f"industries.csv  -> {len(INDUSTRIES_DATA)} rows")

# ---------------------------------------------------------------------------
# 2. Products
# ---------------------------------------------------------------------------

with open(os.path.join(OUT, "products.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["productId", "name", "pillar", "monthlyFee"])
    for row in PRODUCTS_DATA:
        w.writerow(row)

print(f"products.csv    -> {len(PRODUCTS_DATA)} rows")

# ---------------------------------------------------------------------------
# 3. Banked Customers
# ---------------------------------------------------------------------------

NUM_BANKED = 500
used_names: set[str] = set()
banked_customers = []

for i in range(1, NUM_BANKED + 1):
    cid = f"CUST-{i:05d}"
    name = unique_name(used_names)
    reg = f"{random.randint(1980, 2024)}/{random.randint(100000, 999999)}/07"
    region = random.choice(PROVINCES)
    segment = random.choices(SEGMENTS, weights=[60, 30, 10])[0]
    turnover = rand_zar(500_000, 500_000_000)
    risk = round(random.uniform(0.01, 0.99), 2)
    ind = random.choice(INDUSTRIES_DATA)[0]
    banked_customers.append((cid, name, reg, region, segment, "banked", turnover, risk, ind))

with open(os.path.join(OUT, "customers_banked.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["customerId", "name", "registrationNumber", "region", "segment", "status", "turnover", "riskScore", "sicCode"])
    for row in banked_customers:
        w.writerow(row)

print(f"customers_banked.csv -> {NUM_BANKED} rows")

# ---------------------------------------------------------------------------
# 4. Unbanked Entities (with planted near-duplicates for entity resolution)
# ---------------------------------------------------------------------------

NUM_UNBANKED = 300
NUM_PLANTED_DUPLICATES = 40
# First N planted pairs: near-identical names + same region/industry → ER confidence >= ~0.70
# with standard weights in 06_entity_resolution.cypher (trading Jaccard stays low in noisy data).
NUM_HIGH_CONFIDENCE_ER_PAIRS = 15

duplicate_sources = random.sample(banked_customers, NUM_PLANTED_DUPLICATES)
duplicate_pairs: list[tuple[str, str, str, str]] = []

unbanked_entities = []

for i in range(1, NUM_UNBANKED + 1):
    cid = f"UNB-{i:05d}"

    if i <= NUM_PLANTED_DUPLICATES:
        source = duplicate_sources[i - 1]
        source_cid, source_name = source[0], source[1]
        source_region, source_sic = source[3], source[8]

        if i <= NUM_HIGH_CONFIDENCE_ER_PAIRS:
            name = create_high_confidence_name_variant(source_name, i)
            region = source_region
            ind = source_sic
        else:
            name = create_name_variant(source_name)
            region = source_region if random.random() < 0.75 else random.choice(PROVINCES)
            ind = source_sic if random.random() < 0.80 else random.choice(INDUSTRIES_DATA)[0]

        used_names.add(name)

        duplicate_pairs.append((source_cid, cid, source_name, name))
    else:
        name = unique_name(used_names)
        region = random.choice(PROVINCES)
        ind = random.choice(INDUSTRIES_DATA)[0]

    unbanked_entities.append((cid, name, "", region, "", "unbanked", "", "", ind))

with open(os.path.join(OUT, "entities_unbanked.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["customerId", "name", "registrationNumber", "region", "segment", "status", "turnover", "riskScore", "sicCode"])
    for row in unbanked_entities:
        w.writerow(row)

with open(os.path.join(OUT, "er_ground_truth.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["bankedCustomerId", "unbankedEntityId", "bankedName", "unbankedVariantName"])
    for pair in duplicate_pairs:
        w.writerow(pair)

print(
    f"entities_unbanked.csv -> {NUM_UNBANKED} rows "
    f"({NUM_PLANTED_DUPLICATES} planted near-duplicates, "
    f"{NUM_HIGH_CONFIDENCE_ER_PAIRS} high-confidence ER name variants)"
)
print(f"er_ground_truth.csv   -> {len(duplicate_pairs)} ground-truth pairs")

# ---------------------------------------------------------------------------
# 5. Accounts (each banked customer gets 1-3 accounts)
# ---------------------------------------------------------------------------

ACCOUNT_TYPES = ["cheque", "savings", "overdraft", "loan"]
accounts = []
cust_accounts: dict[str, list[str]] = {}

acc_counter = 0
for cid, *_ in banked_customers:
    n_acc = random.choices([1, 2, 3], weights=[50, 35, 15])[0]
    for _ in range(n_acc):
        acc_counter += 1
        aid = f"ACC-{acc_counter:06d}"
        atype = random.choice(ACCOUNT_TYPES)
        odate = rand_date(date(2010, 1, 1), date(2024, 12, 31))
        bal = rand_zar(1_000, 10_000_000)
        accounts.append((aid, cid, atype, odate.isoformat(), bal))
        cust_accounts.setdefault(cid, []).append(aid)

# Give unbanked entities a pseudo-account for transaction linkage
for cid, *_ in unbanked_entities:
    acc_counter += 1
    aid = f"ACC-{acc_counter:06d}"
    odate = rand_date(date(2015, 1, 1), date(2024, 12, 31))
    bal = rand_zar(0, 2_000_000)
    accounts.append((aid, cid, "external", odate.isoformat(), bal))
    cust_accounts.setdefault(cid, []).append(aid)

with open(os.path.join(OUT, "accounts.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["accountId", "customerId", "accountType", "openDate", "balance"])
    for row in accounts:
        w.writerow(row)

print(f"accounts.csv    -> {len(accounts)} rows")

# ---------------------------------------------------------------------------
# Transaction helpers
# ---------------------------------------------------------------------------

all_banked_ids = [c[0] for c in banked_customers]
all_unbanked_ids = [c[0] for c in unbanked_entities]
all_ids = all_banked_ids + all_unbanked_ids

def pick_sender_receiver(allow_unbanked_sender=False):
    sender = random.choice(all_banked_ids)
    if random.random() < 0.35:
        receiver = random.choice(all_unbanked_ids)
    else:
        receiver = random.choice(all_banked_ids)
        while receiver == sender:
            receiver = random.choice(all_banked_ids)
    if allow_unbanked_sender and random.random() < 0.15:
        sender, receiver = receiver, sender
    return sender, receiver

def pick_account(cid):
    accs = cust_accounts.get(cid, [])
    return random.choice(accs) if accs else "ACC-000000"

tx_counter = 0

def gen_tx_id(prefix):
    global tx_counter
    tx_counter += 1
    return f"{prefix}-{tx_counter:07d}"

# ---------------------------------------------------------------------------
# 6. EFT Transactions
# ---------------------------------------------------------------------------

NUM_EFT = 15000
eft_rows = []
for _ in range(NUM_EFT):
    sender, receiver = pick_sender_receiver(allow_unbanked_sender=True)
    tid = gen_tx_id("EFT")
    amt = rand_zar(500, 5_000_000)
    d = rand_date(date(2023, 1, 1), date(2024, 12, 31))
    ref = random.choice(EFT_REFERENCES)
    eft_rows.append((tid, pick_account(sender), pick_account(receiver), amt, "ZAR", d.isoformat(), "EFT", ref))

# Plant overlap transactions: shared banked counterparties pay/refund both entities in the pair.
# High-confidence ER pairs get more shared counterparties; trading Jaccard is still usually small
# versus random traffic, so those pairs rely on strong legal-name variants (see NUM_HIGH_CONFIDENCE_ER_PAIRS).
planted_overlap = 0
for pair_index, (banked_cid, unbanked_cid, _, _) in enumerate(duplicate_pairs):
    n_shared = (
        random.randint(18, 28)
        if pair_index < NUM_HIGH_CONFIDENCE_ER_PAIRS
        else random.randint(3, 5)
    )
    pool = [c for c in all_banked_ids if c != banked_cid]
    shared = random.sample(pool, min(n_shared, len(pool)))
    for cp_cid in shared:
        for target_cid in (unbanked_cid, banked_cid):
            tid = gen_tx_id("EFT")
            amt = rand_zar(500, 5_000_000)
            d = rand_date(date(2023, 1, 1), date(2024, 12, 31))
            ref = random.choice(EFT_REFERENCES)
            eft_rows.append((tid, pick_account(cp_cid), pick_account(target_cid),
                             amt, "ZAR", d.isoformat(), "EFT", ref))
            planted_overlap += 1

with open(os.path.join(OUT, "transactions_eft.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["transactionId", "senderAccountId", "receiverAccountId", "amount", "currency", "date", "channel", "reference"])
    for row in eft_rows:
        w.writerow(row)

print(f"transactions_eft.csv -> {len(eft_rows)} rows ({planted_overlap} planted for ER overlap)")

# ---------------------------------------------------------------------------
# 7. NAV Transactions
# ---------------------------------------------------------------------------

NUM_NAV = 10000
nav_rows = []
for _ in range(NUM_NAV):
    sender, receiver = pick_sender_receiver()
    tid = gen_tx_id("NAV")
    amt = rand_zar(1_000, 20_000_000)
    d = rand_date(date(2023, 1, 1), date(2024, 12, 31))
    nav_rows.append((tid, pick_account(sender), pick_account(receiver), amt, "ZAR", d.isoformat(), "NAV", "CLEARING"))

with open(os.path.join(OUT, "transactions_nav.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["transactionId", "senderAccountId", "receiverAccountId", "amount", "currency", "date", "channel", "reference"])
    for row in nav_rows:
        w.writerow(row)

print(f"transactions_nav.csv -> {NUM_NAV} rows")

# ---------------------------------------------------------------------------
# 8. SOF Transactions
# ---------------------------------------------------------------------------

NUM_SOF = 8000
sof_rows = []
for _ in range(NUM_SOF):
    sender, receiver = pick_sender_receiver()
    tid = gen_tx_id("SOF")
    amt = rand_zar(10_000, 50_000_000)
    d = rand_date(date(2023, 1, 1), date(2024, 12, 31))
    sof_rows.append((tid, pick_account(sender), pick_account(receiver), amt, "ZAR", d.isoformat(), "SOF", "SOURCE OF FUNDS"))

with open(os.path.join(OUT, "transactions_sof.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["transactionId", "senderAccountId", "receiverAccountId", "amount", "currency", "date", "channel", "reference"])
    for row in sof_rows:
        w.writerow(row)

print(f"transactions_sof.csv -> {NUM_SOF} rows")

# ---------------------------------------------------------------------------
# 9. SWIFT Transactions
# ---------------------------------------------------------------------------

NUM_SWIFT = 2000
swift_rows = []
for _ in range(NUM_SWIFT):
    sender, receiver = pick_sender_receiver(allow_unbanked_sender=True)
    tid = gen_tx_id("SWF")
    amt = rand_zar(50_000, 100_000_000)
    cur = random.choice(SWIFT_CURRENCIES)
    d = rand_date(date(2023, 1, 1), date(2024, 12, 31))
    direction = random.choice(["INWARD", "OUTWARD"])
    swift_rows.append((tid, pick_account(sender), pick_account(receiver), amt, cur, d.isoformat(), "SWIFT", direction))

with open(os.path.join(OUT, "transactions_swift.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["transactionId", "senderAccountId", "receiverAccountId", "amount", "currency", "date", "channel", "reference"])
    for row in swift_rows:
        w.writerow(row)

print(f"transactions_swift.csv -> {NUM_SWIFT} rows")

# ---------------------------------------------------------------------------
# 10. Product Holdings (banked customers only, 1-5 products each)
# ---------------------------------------------------------------------------

product_ids = [p[0] for p in PRODUCTS_DATA]
product_holdings = []

for cid, *_ in banked_customers:
    n_products = random.randint(1, 5)
    held = random.sample(product_ids, n_products)
    for pid in held:
        since = rand_date(date(2012, 1, 1), date(2024, 12, 31))
        product_holdings.append((cid, pid, since.isoformat()))

with open(os.path.join(OUT, "product_holdings.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["customerId", "productId", "since"])
    for row in product_holdings:
        w.writerow(row)

print(f"product_holdings.csv -> {len(product_holdings)} rows")

print("\nDone. All CSV files written to data/")
