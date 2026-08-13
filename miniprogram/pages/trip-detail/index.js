const store = require('../../utils/archive-store')
const { recordViewModel } = require('../../utils/presentation')

Page({
  data: {
    id: '',
    trip: null,
    items: []
  },

  onLoad(options) {
    this.setData({ id: decodeURIComponent(options.id || '') })
  },

  onShow() {
    const trip = store.getTrip(this.data.id)
    const items = store.recordsForTrip(this.data.id).map(({ placement, record }) => ({
      ...recordViewModel(record),
      day: placement.day
    }))
    this.setData({ trip, items })
  },

  goBack() {
    wx.navigateBack()
  },

  openDetail(event) {
    wx.navigateTo({ url: `/pages/detail/index?id=${encodeURIComponent(event.currentTarget.dataset.id)}` })
  },

  addStub() {
    wx.navigateTo({ url: `/pages/editor/index?tripId=${encodeURIComponent(this.data.id)}` })
  }
})
