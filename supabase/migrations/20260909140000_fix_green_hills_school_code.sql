-- 20260909140000_fix_green_hills_school_code.sql
-- The "Green Hills Academic Complex" institutions row had school_code =
-- NULL (seeded directly rather than created through
-- SchoolRepository.create(), which does set it correctly). Every
-- account tied to this institution passed voucher redemption fine
-- (school_vouchers.school_code and Branding.current.voucherPrefix are
-- both 'GH', independent columns/values from this one), but failed
-- AuthService._assertBelongsToThisBrand() on every subsequent login:
-- that check compares institutions.school_code against the app's
-- voucherPrefix, and '' (school_code coerced from null) != 'GH' always
-- reads as a cross-brand mismatch, permanently blocking sign-in with
-- "This account isn't linked to Green Hills Academic Complex" --
-- exactly the bug the user reported (redeem voucher -> log out -> log
-- back in -> locked out).
--
-- Confirmed via query: this is the only GH/LB-era institution with a
-- null school_code that actually has redeemed vouchers against it (a
-- second null-code row, "My School", has zero vouchers and is left
-- alone -- not implicated in this bug, not touched here).

update public.institutions
set school_code = 'GH'
where id = '93f2afa1-aaa1-4d15-86e8-41a15b1f94c2'
  and school_name = 'Green Hills Academic Complex'
  and school_code is null;
