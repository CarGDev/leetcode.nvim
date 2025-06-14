local utils = require("leetcode.api.utils")
local log = require("leetcode.logger")
local queries = require("leetcode.api.queries")
local problemlist = require("leetcode.cache.problemlist")
local urls = require("leetcode.api.urls")

local question = {}

---@class lc.Question.Content
---@field content string

---@param title_slug string
---
---@return lc.question_res|nil
function question.by_title_slug(title_slug)
    local variables = {
        titleSlug = title_slug,
    }

    local query = queries.question

    local res, err = utils.query(query, variables)
    if not res or err then
        return log.err(err)
    end

    local q = res.data.question
    q.meta_data = select(2, pcall(utils.decode, q.meta_data))
    q.stats = select(2, pcall(utils.decode, q.stats))
    if type(q.similar) == "string" then
        q.similar = utils.normalize_similar_cn(q.similar)
    end

    return q
end

---@param filters? table
function question.random(filters)
    local variables = {
        categorySlug = "algorithms",
        filters = filters or vim.empty_dict(),
    }

    local query = queries.random_question

    local config = require("leetcode.config")
    local res, err = utils.query(query, variables)
    if err then
        return nil, err
    end

    local q = res.data.randomQuestion

    if q == vim.NIL then
        local msg = "Random question fetch responded with `null`"

        if filters then
            msg = msg .. ".\n\nMaybe invalid filters?\n" .. vim.inspect(filters)
        end

        return nil, { msg = msg, lvl = vim.log.levels.ERROR }
    end

    if config.is_cn then
        q = {
            title_slug = q,
            paid_only = problemlist.get_by_title_slug(q).paid_only,
        }
    end

    if not config.auth.is_premium and q.paid_only then
        err = err or {}
        err.msg = "Drawn question is for premium users only. Please try again"
        err.lvl = vim.log.levels.WARN
        return nil, err
    end

    return q
end

---@param qid integer
---@param lang lc.lang
---@param cb function
function question.latest_submission(qid, lang, cb)
    local url = urls.latest_submission:format(qid, lang)
    utils.get(url, { callback = cb })
end

---@param qid integer
---@param lang integer
---@param cb function
function question.synced_code(qid, lang, cb)
    local variables = {
        questionId = qid,
        lang = lang
    }

    local query = queries.synced_code
    log.info('Query' .. query)
    log.info(lang)

    utils.query(query, variables, {
        callback = function(res, err)
            if err then
                return cb(nil, err)
            end

            if not res.data or not res.data.syncedCode then
                return cb(nil, { msg = "No synced code found" })
            end
            log.info(res.data)

            cb(res.data.syncedCode)
        end
    })
end

return question
