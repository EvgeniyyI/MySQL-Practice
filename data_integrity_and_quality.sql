USE social_center;

-- =============================================
-- 1. Orphan Records
-- =============================================

-- Клиенты без пользователя
SELECT 'Clients without User' AS issue_type, COUNT(*) AS count 
FROM clients WHERE user_id IS NULL;

-- Пользователи без person_data
SELECT 'Users without Person' AS issue_type, COUNT(*) AS count 
FROM users WHERE person_id IS NULL;

-- Person_data без паспорта
SELECT 'Person without Passport' AS issue_type, COUNT(*) AS count 
FROM person_data WHERE passport_data_id IS NULL;

-- Заявки без клиента
SELECT 'Applications without Client' AS issue_type, COUNT(*) AS count 
FROM applications WHERE client_id IS NULL;

-- =============================================
-- 2. Дубликаты
-- =============================================

-- Дубли логинов
SELECT login, COUNT(*) AS duplicates 
FROM users 
GROUP BY login 
HAVING COUNT(*) > 1;

-- Дубли номеров паспортов
SELECT series, number, COUNT(*) 
FROM passport_data 
GROUP BY series, number 
HAVING COUNT(*) > 1;

-- Дубли назначенных услуг по одной заявке
SELECT 
    application_id, 
    service_id, 
    COUNT(*) AS duplicates
FROM client_services 
GROUP BY application_id, service_id 
HAVING COUNT(*) > 1;

-- =============================================
-- 3. Проверка бизнес-правил и аномалий
-- =============================================

-- Заявки в будущем
SELECT * FROM applications 
WHERE submittedAt > NOW();

-- updated_at раньше created_at
SELECT * FROM clients 
WHERE updated_at IS NOT NULL AND updated_at < created_at;

-- Отзывы с некорректными оценками
SELECT 
    id,
    client_service_id,
    ratingOverall,
    ratingQuality,
    ratingWorker,
    wouldRecommend
FROM client_service_feedback 
WHERE ratingOverall NOT BETWEEN 1 AND 5 
   OR ratingQuality NOT BETWEEN 1 AND 5 
   OR ratingWorker NOT BETWEEN 1 AND 5;

-- =============================================
-- 4. Window Functions для поиска аномалий
-- =============================================

-- Поиск повторяющихся статусов подряд у клиента
WITH client_applications AS (
    SELECT 
        client_id,
        submittedAt,
        status,
        LAG(status) OVER (PARTITION BY client_id ORDER BY submittedAt) AS prev_status
    FROM applications
)
SELECT * 
FROM client_applications 
WHERE status = prev_status;

-- Поиск клиентов с резкими изменениями приоритета
WITH client_history AS (
    SELECT 
        client_id,
        priority,
        created_at,
        LAG(priority) OVER (PARTITION BY client_id ORDER BY created_at) AS prev_priority
    FROM clients
)
SELECT *
FROM client_history 
WHERE priority != prev_priority 
  AND prev_priority IS NOT NULL;