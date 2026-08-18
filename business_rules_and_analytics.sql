USE social_center;

-- =============================================
-- 1. Статистика и отчёты
-- =============================================

-- Статистика по заявкам
SELECT 
    status,
    category,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM applications 
GROUP BY status, category
ORDER BY count DESC;

-- Нагрузка на социальных работников
SELECT 
    u.login,
    u.role,
    COUNT(DISTINCT cs.id) AS services_assigned,
    COUNT(DISTINCT p.id) AS plans_assigned,
    AVG(f.ratingOverall) AS avg_rating
FROM users u
LEFT JOIN client_services cs ON cs.worker_id = u.id
LEFT JOIN patronage_plans p ON p.assigned_user = u.id
LEFT JOIN client_service_feedback f ON f.worker_id = u.id
WHERE u.role = 'SOCIAL_WORKER'
GROUP BY u.id, u.login, u.role
HAVING COUNT(DISTINCT cs.id) > 0
ORDER BY services_assigned DESC;

-- Статистика по категориям клиентов и услугам
SELECT 
    c.priority,
    COUNT(DISTINCT c.id) AS client_count,
    COUNT(cs.id) AS services_assigned,
    AVG(f.ratingOverall) AS avg_satisfaction
FROM clients c
LEFT JOIN applications a ON a.client_id = c.id
LEFT JOIN client_services cs ON cs.application_id = a.id
LEFT JOIN client_service_feedback f ON f.client_service_id = cs.id
GROUP BY c.priority
ORDER BY client_count DESC;

-- =============================================
-- 2. Проверка важных бизнес-правил
-- =============================================

-- Высокий приоритет, но нет услуг
SELECT DISTINCT c.id, c.priority
FROM clients c
WHERE c.priority IN ('HIGH', 'URGENT')
  AND NOT EXISTS (
      SELECT 1 FROM applications a 
      JOIN client_services cs ON cs.application_id = a.id 
      WHERE a.client_id = c.id
  );

-- Клиенты с заявками, но без назначенных услуг
SELECT 
    c.id AS client_id,
    COUNT(a.id) AS applications_count,
    'Has applications but no services' AS issue
FROM clients c
JOIN applications a ON a.client_id = c.id
WHERE NOT EXISTS (
    SELECT 1 FROM client_services cs 
    WHERE cs.application_id = a.id
)
GROUP BY c.id;

-- Отзывы с низкой оценкой, но рекомендацией
SELECT 
    f.id,
    f.ratingOverall,
    f.wouldRecommend,
    u.login AS worker
FROM client_service_feedback f
JOIN client_services cs ON f.client_service_id = cs.id
JOIN users u ON cs.worker_id = u.id
WHERE f.wouldRecommend = 1 
  AND f.ratingOverall <= 3;
  
-- =============================================
-- 3. Window Functions — ранжирование и аналитика
-- =============================================

-- Топ работников по количеству услуг
WITH worker_stats AS (
    SELECT 
        worker_id,
        COUNT(*) AS service_count,
        AVG(ratingOverall) AS avg_rating
    FROM client_services cs
    JOIN client_service_feedback f ON f.client_service_id = cs.id
    GROUP BY worker_id
)
SELECT 
    u.login,
    ws.service_count,
    ws.avg_rating,
    RANK() OVER (ORDER BY ws.service_count DESC) AS rank_by_volume,
    RANK() OVER (ORDER BY ws.avg_rating DESC) AS rank_by_rating
FROM worker_stats ws
JOIN users u ON u.id = ws.worker_id
ORDER BY rank_by_volume;

-- Динамика заявок по месяцам
SELECT 
    DATE_FORMAT(submittedAt, '%Y-%m') AS month,
    COUNT(*) AS applications_count,
    COUNT(CASE WHEN status = 'APPROVED' THEN 1 END) AS approved_count,
    ROUND(COUNT(CASE WHEN status = 'APPROVED' THEN 1 END) * 100.0 / COUNT(*), 2) AS approval_rate,
    LAG(COUNT(*)) OVER (ORDER BY DATE_FORMAT(submittedAt, '%Y-%m')) AS prev_month_count
FROM applications
GROUP BY DATE_FORMAT(submittedAt, '%Y-%m')
ORDER BY month DESC;

-- =============================================
-- 4. Дополнительные аналитические запросы
-- =============================================

-- Распределение услуг по категориям
SELECT 
    s.category,
    COUNT(cs.id) AS total_assigned,
    COUNT(DISTINCT cs.application_id) AS unique_applications,
    AVG(cs.frequency_planned) AS avg_planned_frequency
FROM services s
LEFT JOIN client_services cs ON cs.service_id = s.id
GROUP BY s.category
ORDER BY total_assigned DESC;

-- Клиенты с наибольшим количеством взаимодействий
SELECT 
    c.id AS client_id,
    COUNT(DISTINCT a.id) AS applications,
    COUNT(DISTINCT cs.id) AS services,
    COUNT(DISTINCT p.id) AS patronage_plans,
    (COUNT(DISTINCT a.id) + COUNT(DISTINCT cs.id)) AS total_activity
FROM clients c
LEFT JOIN applications a ON a.client_id = c.id
LEFT JOIN client_services cs ON cs.application_id = a.id
LEFT JOIN patronage_plans p ON p.client_id = c.id
GROUP BY c.id
ORDER BY total_activity DESC
LIMIT 15;