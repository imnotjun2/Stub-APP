import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync } from 'node:child_process'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const maxBundledMediaBytes = 200 * 1024
const bundledMediaExtensions = new Set([
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.bmp',
  '.mp3',
  '.wav',
  '.aac',
  '.m4a',
])

function fail(message) {
  throw new Error(message)
}

function readJSON(relativePath) {
  const absolutePath = path.join(root, relativePath)
  try {
    return JSON.parse(fs.readFileSync(absolutePath, 'utf8'))
  } catch (error) {
    fail(`${relativePath} 不是有效 JSON：${error.message}`)
  }
}

function walk(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const target = path.join(directory, entry.name)
    return entry.isDirectory() ? walk(target) : [target]
  })
}

function validateWXML(relativePath) {
  const source = fs.readFileSync(path.join(root, relativePath), 'utf8')
  const openingBindings = (source.match(/\{\{/g) || []).length
  const closingBindings = (source.match(/\}\}/g) || []).length
  if (openingBindings !== closingBindings) fail(`${relativePath} 的数据绑定括号不平衡`)

  const stack = []
  const tokens = source.match(/<\/?[a-zA-Z-]+(?:\s[^<>]*?)?\/?>/g) || []
  for (const token of tokens) {
    const name = token.match(/^<\/?([a-zA-Z-]+)/)[1]
    if (token.startsWith('</')) {
      const last = stack.pop()
      if (last !== name) fail(`${relativePath} 标签不平衡：期望 </${last}>，实际为 </${name}>`)
    } else if (!token.endsWith('/>')) {
      stack.push(name)
    }
  }
  if (stack.length) fail(`${relativePath} 存在未闭合标签：${stack.join(', ')}`)
}

const app = readJSON('app.json')
const projectConfig = readJSON('project.config.json')
readJSON('sitemap.json')

if (!Array.isArray(app.pages) || app.pages.length < 4) fail('app.json 至少需要四个页面')
if (!app.tabBar || !Array.isArray(app.tabBar.list)) fail('app.json 缺少 tabBar')

for (const page of app.pages) {
  for (const extension of ['js', 'json', 'wxml', 'wxss']) {
    const relativePath = `${page}.${extension}`
    if (!fs.existsSync(path.join(root, relativePath))) fail(`缺少页面文件：${relativePath}`)
    if (extension === 'json') readJSON(relativePath)
    if (extension === 'wxml') validateWXML(relativePath)
  }
}

for (const item of app.tabBar.list) {
  if (!app.pages.includes(item.pagePath)) fail(`tabBar 页面未在 pages 中注册：${item.pagePath}`)
  for (const field of ['iconPath', 'selectedIconPath']) {
    if (!item[field]) fail(`tabBar ${item.pagePath} 缺少 ${field}`)
    if (!fs.existsSync(path.join(root, item[field]))) fail(`tabBar 图标不存在：${item[field]}`)
  }
}

const jsFiles = walk(root).filter((file) => file.endsWith('.js') || file.endsWith('.cjs') || file.endsWith('.mjs'))
for (const file of jsFiles) {
  const result = spawnSync(process.execPath, ['--check', file], { encoding: 'utf8' })
  if (result.status !== 0) fail(`${path.relative(root, file)} 语法检查失败：\n${result.stderr}`)
}

const routePattern = /\/pages\/[a-z-]+\/index/g
for (const file of jsFiles.filter((item) => item.includes(`${path.sep}pages${path.sep}`))) {
  const source = fs.readFileSync(file, 'utf8')
  for (const route of source.match(routePattern) || []) {
    const normalized = route.slice(1)
    if (!app.pages.includes(normalized)) fail(`${path.relative(root, file)} 跳转到未注册页面：${route}`)
  }
}

for (const asset of ['movie-poster.jpg', 'boarding-pass.jpg', 'ramen.jpg', 'trip-map.jpg']) {
  if (!fs.existsSync(path.join(root, 'assets', asset))) fail(`缺少示例素材：assets/${asset}`)
}

const packIgnoreRules = projectConfig.packOptions?.ignore || []

function isIgnoredFromPack(file) {
  const relativePath = path.relative(root, file).split(path.sep).join('/')
  return packIgnoreRules.some((rule) => {
    if (rule.type === 'file') return relativePath === rule.value
    if (rule.type === 'folder') return relativePath === rule.value || relativePath.startsWith(`${rule.value}/`)
    if (rule.type === 'suffix') return relativePath.endsWith(rule.value)
    if (rule.type === 'prefix') return relativePath.startsWith(rule.value)
    if (rule.type === 'regexp') return new RegExp(rule.value).test(relativePath)
    return false
  })
}

for (const file of walk(root)) {
  if (isIgnoredFromPack(file)) continue

  const extension = path.extname(file).toLowerCase()
  const size = fs.statSync(file).size
  const isMedia = bundledMediaExtensions.has(extension)
  const isOpaqueResource = extension === ''
  if ((isMedia || isOpaqueResource) && size > maxBundledMediaBytes) {
    const relativePath = path.relative(root, file)
    const sizeInKB = (size / 1024).toFixed(1)
    fail(`${relativePath} 为 ${sizeInKB} KB，可能作为图片/音频资源进入微信代码包并超过 200 KB 限制`)
  }
}

console.log(`Stub 小程序检查通过：${app.pages.length} 个页面，${jsFiles.length} 个脚本。`)
