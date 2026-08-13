const store = require('../../utils/archive-store')

const CATEGORIES = [
  { id: 'movie', label: '电影' },
  { id: 'travel', label: '旅行' },
  { id: 'exhibition', label: '展览' },
  { id: 'food', label: '餐饮' },
  { id: 'shopping', label: '购物' },
  { id: 'other', label: '其他' }
]

const SUBTYPES = [
  { id: 'flight', label: '机票' },
  { id: 'train', label: '火车票' }
]

const TAGS = ['首映', '和朋友', '独自出发', '雨天', '值得重温', '好吃']
const FORMATS = ['IMAX', 'Dolby Cinema', 'CINITY', '4DX']

function today() {
  const now = new Date()
  const local = new Date(now.getTime() - now.getTimezoneOffset() * 60 * 1000)
  return local.toISOString().slice(0, 10)
}

function emptyForm() {
  return {
    title: '',
    occurredOn: today(),
    category: 'other',
    subtype: 'flight',
    note: '',
    tags: [],
    tripId: '',
    details: {
      cinema: '',
      hall: '',
      seat: '',
      format: '',
      number: '',
      departure: '',
      arrival: '',
      location: ''
    }
  }
}

Page({
  data: {
    editingId: '',
    form: emptyForm(),
    ticketPath: '',
    originalMedia: null,
    categories: CATEGORIES,
    categoryIndex: 5,
    subtypes: SUBTYPES,
    subtypeIndex: 0,
    tagOptions: TAGS.map((label) => ({ label, selected: false })),
    formatOptions: FORMATS.map((label) => ({ label, selected: false })),
    tripOptions: [{ id: '', title: '不加入旅册' }],
    tripIndex: 0,
    saving: false
  },

  onLoad(options) {
    const archive = store.getArchive()
    const tripOptions = [{ id: '', title: '不加入旅册' }, ...archive.trips]
    const editingId = decodeURIComponent(options.id || '')
    const requestedTripId = decodeURIComponent(options.tripId || '')
    const existing = editingId ? store.getRecord(editingId) : null

    if (existing && existing.source === 'user') {
      const placement = archive.placements.find((item) => item.stubId === existing.id)
      const tripId = placement ? placement.tripId : ''
      const form = {
        title: existing.title,
        occurredOn: existing.occurredOn,
        category: existing.category,
        subtype: existing.subtype || 'flight',
        note: existing.note || '',
        tags: existing.tags || [],
        tripId,
        details: { ...emptyForm().details, ...(existing.details || {}) }
      }
      this.setData({
        editingId,
        form,
        ticketPath: existing.primaryMedia ? existing.primaryMedia.value : '',
        originalMedia: existing.primaryMedia || null,
        categoryIndex: Math.max(0, CATEGORIES.findIndex((item) => item.id === form.category)),
        subtypeIndex: Math.max(0, SUBTYPES.findIndex((item) => item.id === form.subtype)),
        tagOptions: TAGS.map((label) => ({ label, selected: form.tags.includes(label) })),
        formatOptions: FORMATS.map((label) => ({ label, selected: form.details.format === label })),
        tripOptions,
        tripIndex: Math.max(0, tripOptions.findIndex((item) => item.id === tripId))
      })
      return
    }

    const requestedTripIndex = Math.max(0, tripOptions.findIndex((item) => item.id === requestedTripId))
    const selectedTrip = tripOptions[requestedTripIndex]
    this.setData({
      tripOptions,
      tripIndex: requestedTripIndex,
      'form.tripId': selectedTrip ? selectedTrip.id : ''
    })
  },

  goBack() {
    wx.navigateBack()
  },

  chooseTicket() {
    const onSuccess = (result) => {
      const path = result.tempFiles ? result.tempFiles[0].tempFilePath : result.tempFilePaths[0]
      this.setData({ ticketPath: path })
    }

    if (wx.chooseMedia) {
      wx.chooseMedia({
        count: 1,
        mediaType: ['image'],
        sourceType: ['album', 'camera'],
        sizeType: ['compressed'],
        success: onSuccess,
        fail: (error) => {
          if (!String(error.errMsg || '').includes('cancel')) {
            wx.showToast({ title: '暂时无法读取照片', icon: 'none' })
          }
        }
      })
      return
    }

    wx.chooseImage({
      count: 1,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      success: onSuccess
    })
  },

  previewTicket() {
    if (!this.data.ticketPath) return
    wx.previewImage({ urls: [this.data.ticketPath], current: this.data.ticketPath })
  },

  onInput(event) {
    const field = event.currentTarget.dataset.field
    this.setData({ [`form.${field}`]: event.detail.value })
  },

  onCategoryChange(event) {
    const categoryIndex = Number(event.detail.value)
    this.setData({
      categoryIndex,
      'form.category': CATEGORIES[categoryIndex].id
    })
  },

  onSubtypeChange(event) {
    const subtypeIndex = Number(event.detail.value)
    this.setData({
      subtypeIndex,
      'form.subtype': SUBTYPES[subtypeIndex].id
    })
  },

  onDateChange(event) {
    this.setData({ 'form.occurredOn': event.detail.value })
  },

  onTripChange(event) {
    const tripIndex = Number(event.detail.value)
    this.setData({
      tripIndex,
      'form.tripId': this.data.tripOptions[tripIndex].id
    })
  },

  toggleTag(event) {
    const label = event.currentTarget.dataset.label
    const tags = this.data.form.tags.includes(label)
      ? this.data.form.tags.filter((item) => item !== label)
      : [...this.data.form.tags, label]
    this.setData({
      'form.tags': tags,
      tagOptions: TAGS.map((item) => ({ label: item, selected: tags.includes(item) }))
    })
  },

  chooseFormat(event) {
    const format = event.currentTarget.dataset.label
    const next = this.data.form.details.format === format ? '' : format
    this.setData({
      'form.details.format': next,
      formatOptions: FORMATS.map((label) => ({ label, selected: label === next }))
    })
  },

  async saveRecord() {
    if (this.data.saving) return
    const title = this.data.form.title.trim()
    if (!this.data.ticketPath) {
      wx.showToast({ title: '请先选择一张票据照片', icon: 'none' })
      return
    }
    if (!title) {
      wx.showToast({ title: '请给这枚存根起个名字', icon: 'none' })
      return
    }

    this.setData({ saving: true })
    wx.showLoading({ title: '正在保存' })
    try {
      const persistedPath = await store.saveTicketFile(this.data.ticketPath)
      const previous = this.data.editingId ? store.getRecord(this.data.editingId) : null
      const now = new Date().toISOString()
      const record = {
        schemaVersion: 1,
        id: this.data.editingId || store.uid('stub'),
        source: 'user',
        title,
        occurredOn: this.data.form.occurredOn,
        category: this.data.form.category,
        subtype: this.data.form.category === 'travel' ? this.data.form.subtype : '',
        note: this.data.form.note.trim(),
        tags: this.data.form.tags,
        primaryMedia: { location: 'local', value: persistedPath },
        attachments: previous ? previous.attachments || [] : [],
        posterMedia: null,
        details: { ...this.data.form.details },
        createdAt: previous ? previous.createdAt : now,
        updatedAt: now
      }
      store.upsertRecord(record, this.data.form.tripId)
      wx.hideLoading()
      wx.showToast({ title: '已经留下', icon: 'success' })
      setTimeout(() => wx.navigateBack(), 450)
    } catch (error) {
      wx.hideLoading()
      wx.showToast({ title: error.message || '保存失败', icon: 'none' })
      this.setData({ saving: false })
    }
  }
})
