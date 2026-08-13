const store = require('../../utils/archive-store')
const { recordViewModel } = require('../../utils/presentation')

const MONTHS = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月']

Page({
  data: {
    records: [],
    featured: null,
    remaining: [],
    monthTitle: '八月',
    yearLabel: '2026',
    userCount: 0
  },

  onShow() {
    this.reload()
  },

  reload() {
    const records = store.listRecords().map(recordViewModel)
    const firstDate = records[0] ? new Date(`${records[0].occurredOn}T12:00:00`) : new Date()
    this.setData({
      records,
      featured: records[0] || null,
      remaining: records.slice(1),
      monthTitle: MONTHS[firstDate.getMonth()],
      yearLabel: String(firstDate.getFullYear()),
      userCount: records.filter((record) => record.source === 'user').length
    })
  },

  openEditor() {
    wx.navigateTo({ url: '/pages/editor/index' })
  },

  openDetail(event) {
    const id = event.currentTarget.dataset.id
    wx.navigateTo({ url: `/pages/detail/index?id=${encodeURIComponent(id)}` })
  }
})
