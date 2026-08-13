const CATEGORY_LABELS = {
  movie: '电影',
  travel: '旅行',
  exhibition: '展览',
  food: '餐饮',
  shopping: '购物',
  other: '其他'
}

const CATEGORY_SYMBOLS = {
  movie: '映',
  travel: '行',
  exhibition: '展',
  food: '味',
  shopping: '物',
  other: '记'
}

function formatDate(value) {
  if (!value) return ''
  return value.replace(/-/g, '.')
}

function coverReference(record) {
  if (!record) return null
  return record.posterMedia || (record.attachments || [])[0] || record.primaryMedia || null
}

function metadataLine(record) {
  const details = record.details || {}
  if (record.category === 'movie') {
    return [details.cinema, details.hall, details.seat].filter(Boolean).join(' · ')
  }
  if (record.category === 'travel') {
    return [details.number, details.departure && details.arrival ? `${details.departure} → ${details.arrival}` : '', details.seat]
      .filter(Boolean)
      .join(' · ')
  }
  return details.location || ''
}

function recordViewModel(record) {
  const cover = coverReference(record)
  const isPrimaryArtifact = Boolean(cover && record.primaryMedia && cover === record.primaryMedia)
  return {
    ...record,
    categoryLabel: CATEGORY_LABELS[record.category] || '其他',
    categorySymbol: CATEGORY_SYMBOLS[record.category] || '记',
    dateLabel: formatDate(record.occurredOn),
    cover: cover ? cover.value : '',
    hasCover: Boolean(cover && cover.value),
    coverMode: isPrimaryArtifact ? 'aspectFit' : 'aspectFill',
    metadata: metadataLine(record),
    tags: Array.isArray(record.tags) ? record.tags : []
  }
}

module.exports = {
  CATEGORY_LABELS,
  formatDate,
  coverReference,
  metadataLine,
  recordViewModel
}
