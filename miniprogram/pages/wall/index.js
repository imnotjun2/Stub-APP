const store = require('../../utils/archive-store')
const { recordViewModel } = require('../../utils/presentation')

const FILTERS = [
  { id: 'all', label: '全部' },
  { id: 'movie', label: '电影' },
  { id: 'travel', label: '旅行' },
  { id: 'food', label: '餐饮' },
  { id: 'exhibition', label: '展览' }
]

Page({
  data: {
    allRecords: [],
    records: [],
    filters: FILTERS.map((item, index) => ({ ...item, selected: index === 0 })),
    activeFilter: 'all'
  },

  onShow() {
    const allRecords = store.listRecords().map(recordViewModel)
    this.setData({ allRecords }, () => this.applyFilter())
  },

  applyFilter() {
    const records = this.data.activeFilter === 'all'
      ? this.data.allRecords
      : this.data.allRecords.filter((record) => record.category === this.data.activeFilter)
    this.setData({ records })
  },

  selectFilter(event) {
    const activeFilter = event.currentTarget.dataset.id
    this.setData({
      activeFilter,
      filters: FILTERS.map((item) => ({ ...item, selected: item.id === activeFilter }))
    }, () => this.applyFilter())
  },

  openDetail(event) {
    wx.navigateTo({ url: `/pages/detail/index?id=${encodeURIComponent(event.currentTarget.dataset.id)}` })
  },

  openEditor() {
    wx.navigateTo({ url: '/pages/editor/index' })
  }
})
