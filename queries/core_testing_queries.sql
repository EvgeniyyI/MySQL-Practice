USE social_center;

-- =============================================
-- 1. Базовые выборки и фильтрация
-- =============================================

-- Все активные клиенты с приоритетом
SELECT 
    id, 
    priority, 
    is_active, 
    created_at, 
    updated_at
FROM clients 
WHERE is_active = 1 
ORDER BY priority DESC, created_at DESC;

-- Заявки в определённых статусах
SELECT 
    id,
    category,
    status,
    priority,
    submittedAt
FROM applications 
WHERE status IN ('SUBMITTED', 'APPROVED')
ORDER BY submittedAt DESC
LIMIT 50;

-- Услуги с фильтрацией по категории и бесплатности
SELECT 
    id,
    name,
    category,
    is_free,
    norm_frequency,
    norm_volume
FROM services 
WHERE is_free = 1 
  AND category IN ('PSYCHO', 'REHAB', 'CONSULT')
ORDER BY category, name;

-- =============================================
-- 2. JOIN-ы
-- =============================================

-- Клиент + Пользователь + Персональные данные
SELECT 
    c.id AS client_id,
    c.priority,
    c.is_active,
    u.login,
    u.role,
    p.firstName,
    p.lastName,
    p.surname,
    COALESCE(p.phone, p.email, 'Нет контактов') AS contact
FROM clients c
LEFT JOIN users u ON c.user_id = u.id
LEFT JOIN person_data p ON u.person_id = p.id
ORDER BY c.created_at DESC;

-- Заявки + Клиент + Исполнитель
SELECT 
    a.id AS application_id,
    a.status,
    a.category,
    a.submittedAt,
    c.priority AS client_priority,
    u_sub.login AS submitted_by,
    u_worker.login AS assigned_worker
FROM applications a
INNER JOIN clients c ON a.client_id = c.id
LEFT JOIN users u_sub ON a.user_id = u_sub.id
LEFT JOIN client_services cs ON cs.application_id = a.id
LEFT JOIN users u_worker ON cs.worker_id = u_worker.id
ORDER BY a.submittedAt DESC;

-- Сообщения чата: отправитель, получатель, дата
SELECT 
    m.id,
    m.content,
    m.sentAt,
    sender.login AS sender_login,
    recipient.login AS recipient_login
FROM chat_messages m
JOIN users sender ON m.sender_id = sender.id
JOIN users recipient ON m.recipient_id = recipient.id
ORDER BY m.sentAt DESC
LIMIT 30;

-- =============================================
-- 3. Window Functions
-- =============================================

-- Нумерация заявок клиента по дате
SELECT 
    client_id,
    id AS application_id,
    submittedAt,
    status,
    ROW_NUMBER() OVER (PARTITION BY client_id ORDER BY submittedAt) AS application_number,
    LAG(status) OVER (PARTITION BY client_id ORDER BY submittedAt) AS previous_status
FROM applications
ORDER BY client_id, submittedAt;

-- Рейтинг работников по количеству услуг (с ранжированием)
SELECT 
    worker_id,
    u.login,
    COUNT(*) AS services_count,
    AVG(f.ratingOverall) AS avg_rating,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_by_volume
FROM client_services cs
JOIN users u ON cs.worker_id = u.id
LEFT JOIN client_service_feedback f ON f.client_service_id = cs.id
GROUP BY worker_id, u.login
ORDER BY rank_by_volume;

-- =============================================
-- 4. UNION
-- =============================================

-- Последние изменения в системе (по дате обновления)
SELECT 
    'clients' AS entity,
    id,
    updated_at,
    priority AS extra_info
FROM clients 
WHERE updated_at IS NOT NULL

UNION ALL

SELECT 
    'applications' AS entity,
    id,
    submittedAt AS updated_at,
    status AS extra_info
FROM applications
ORDER BY updated_at DESC
LIMIT 20;