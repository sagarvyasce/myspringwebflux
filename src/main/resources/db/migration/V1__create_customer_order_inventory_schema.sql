-- Application-generated UUIDs keep this migration independent of a database extension.

CREATE TABLE customers (
    id UUID PRIMARY KEY,
    email VARCHAR(320) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(32),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT customers_email_not_blank CHECK (btrim(email) <> ''),
    CONSTRAINT customers_first_name_not_blank CHECK (btrim(first_name) <> ''),
    CONSTRAINT customers_last_name_not_blank CHECK (btrim(last_name) <> '')
);

CREATE UNIQUE INDEX customers_email_lower_uq ON customers (lower(email));

CREATE TABLE customer_addresses (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
    address_type VARCHAR(20) NOT NULL,
    recipient_name VARCHAR(200) NOT NULL,
    line1 VARCHAR(200) NOT NULL,
    line2 VARCHAR(200),
    city VARCHAR(100) NOT NULL,
    region VARCHAR(100),
    postal_code VARCHAR(32) NOT NULL,
    country_code CHAR(2) NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT customer_addresses_type_check CHECK (address_type IN ('BILLING', 'SHIPPING')),
    CONSTRAINT customer_addresses_recipient_not_blank CHECK (btrim(recipient_name) <> ''),
    CONSTRAINT customer_addresses_line1_not_blank CHECK (btrim(line1) <> ''),
    CONSTRAINT customer_addresses_city_not_blank CHECK (btrim(city) <> ''),
    CONSTRAINT customer_addresses_postal_code_not_blank CHECK (btrim(postal_code) <> ''),
    CONSTRAINT customer_addresses_country_code_check CHECK (country_code = upper(country_code))
);

CREATE INDEX customer_addresses_customer_idx ON customer_addresses (customer_id);
CREATE UNIQUE INDEX customer_addresses_default_uq
    ON customer_addresses (customer_id, address_type)
    WHERE is_default;

CREATE TABLE orders (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL,
    billing_address_id UUID,
    shipping_address_id UUID,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    currency_code CHAR(3) NOT NULL,
    subtotal_minor BIGINT NOT NULL,
    shipping_minor BIGINT NOT NULL DEFAULT 0,
    tax_minor BIGINT NOT NULL DEFAULT 0,
    total_minor BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT orders_status_check CHECK (status IN ('PENDING', 'CONFIRMED', 'PAID', 'FULFILLED', 'CANCELLED')),
    CONSTRAINT orders_currency_code_check CHECK (currency_code = upper(currency_code)),
    CONSTRAINT orders_amounts_non_negative CHECK (
        subtotal_minor >= 0 AND shipping_minor >= 0 AND tax_minor >= 0 AND total_minor >= 0
    ),
    CONSTRAINT orders_total_matches_components CHECK (
        total_minor = subtotal_minor + shipping_minor + tax_minor
    )
);

-- customer_id and address IDs are owned by the Customer service; no cross-context FKs.
CREATE INDEX orders_customer_created_idx ON orders (customer_id, created_at DESC);
CREATE INDEX orders_status_created_idx ON orders (status, created_at DESC);

CREATE TABLE order_items (
    id UUID PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    product_sku_id UUID NOT NULL,
    sku_code_snapshot VARCHAR(100) NOT NULL,
    product_name_snapshot VARCHAR(200) NOT NULL,
    unit_price_minor BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    line_total_minor BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT order_items_unit_price_non_negative CHECK (unit_price_minor >= 0),
    CONSTRAINT order_items_quantity_positive CHECK (quantity > 0),
    CONSTRAINT order_items_line_total_matches CHECK (line_total_minor = unit_price_minor * quantity),
    CONSTRAINT order_items_sku_snapshot_not_blank CHECK (btrim(sku_code_snapshot) <> ''),
    CONSTRAINT order_items_product_snapshot_not_blank CHECK (btrim(product_name_snapshot) <> '')
);

CREATE INDEX order_items_order_idx ON order_items (order_id);
CREATE INDEX order_items_product_sku_idx ON order_items (product_sku_id);

CREATE TABLE order_status_history (
    id UUID PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100),
    note VARCHAR(500),
    CONSTRAINT order_status_history_status_check CHECK (status IN ('PENDING', 'CONFIRMED', 'PAID', 'FULFILLED', 'CANCELLED'))
);

CREATE INDEX order_status_history_order_changed_idx
    ON order_status_history (order_id, changed_at DESC);

CREATE TABLE products (
    id UUID PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT products_name_not_blank CHECK (btrim(name) <> '')
);

CREATE TABLE product_skus (
    id UUID PRIMARY KEY,
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    sku_code VARCHAR(100) NOT NULL,
    price_minor BIGINT NOT NULL,
    currency_code CHAR(3) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT product_skus_code_not_blank CHECK (btrim(sku_code) <> ''),
    CONSTRAINT product_skus_price_non_negative CHECK (price_minor >= 0),
    CONSTRAINT product_skus_currency_code_check CHECK (currency_code = upper(currency_code))
);

CREATE UNIQUE INDEX product_skus_code_uq ON product_skus (lower(sku_code));
CREATE INDEX product_skus_product_idx ON product_skus (product_id);

CREATE TABLE inventory_stock (
    product_sku_id UUID PRIMARY KEY REFERENCES product_skus (id) ON DELETE CASCADE,
    on_hand_quantity INTEGER NOT NULL DEFAULT 0,
    reserved_quantity INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT inventory_stock_quantities_non_negative CHECK (
        on_hand_quantity >= 0 AND reserved_quantity >= 0
    ),
    CONSTRAINT inventory_stock_reserved_within_on_hand CHECK (reserved_quantity <= on_hand_quantity)
);

CREATE TABLE stock_reservations (
    id UUID PRIMARY KEY,
    product_sku_id UUID NOT NULL REFERENCES product_skus (id) ON DELETE RESTRICT,
    order_id UUID NOT NULL,
    quantity INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stock_reservations_quantity_positive CHECK (quantity > 0),
    CONSTRAINT stock_reservations_status_check CHECK (status IN ('ACTIVE', 'RELEASED', 'CONSUMED', 'EXPIRED')),
    CONSTRAINT stock_reservations_active_expiry_check CHECK (
        status <> 'ACTIVE' OR expires_at IS NOT NULL
    )
);

-- order_id belongs to the Order service and intentionally has no cross-context FK.
CREATE INDEX stock_reservations_order_idx ON stock_reservations (order_id);
CREATE INDEX stock_reservations_sku_status_idx ON stock_reservations (product_sku_id, status);
CREATE UNIQUE INDEX stock_reservations_active_order_sku_uq
    ON stock_reservations (order_id, product_sku_id)
    WHERE status = 'ACTIVE';