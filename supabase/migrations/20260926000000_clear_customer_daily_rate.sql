-- Reset daily_rate to 0 for all Customer / GUEST accounts in profiles table
UPDATE profiles
SET daily_rate = 0
WHERE UPPER(role) = 'GUEST'
   OR UPPER(role) = 'CUSTOMER'
   OR LOWER(position) = 'customer'
   OR position IS NULL
   OR position = '';
