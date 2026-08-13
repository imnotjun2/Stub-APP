const store = require('../../utils/archive-store')
const { recordViewModel } = require('../../utils/presentation')

Page({
  data: {
    id: '',
    record: null,
    detailRows: []
  },

  onLoad(options) {
    this.setData({ id: decodeURIComponent(options.id || '') })
  },

  onShow() {
    this.reload()
  },

  reload() {
    const raw = store.getRecord(this.data.id)
    if (!raw) {
      wx.showToast({ title: '这枚存根不存在', icon: 'none' })
      return
    }
    const record = recordViewModel(raw)
    const details = record.details || {}
    const labels = {
      cinema: '影院',
      hall: '影厅',
      seat: '座位',
      format: '格式',
      number: record.subtype === 'flight' ? '航班号' : '车次',
      departure: '出发',
      arrival: '到达',
      location: '地点'
    }
    const detailRows = Object.keys(labels)
      .filter((key) => details[key])
      .map((key) => ({ key, label: labels[key], value: details[key] }))
    this.setData({ record, detailRows })
  },

  goBack() {
    wx.navigateBack()
  },

  editRecord() {
    wx.navigateTo({ url: `/pages/editor/index?id=${encodeURIComponent(this.data.id)}` })
  },

  deleteRecord() {
    wx.showModal({
      title: '移除这枚存根？',
      content: '本地保存的票据照片也会一并删除，此操作无法恢复。',
      confirmText: '删除',
      confirmColor: '#9F342F',
      success: (result) => {
        if (!result.confirm) return
        store.deleteRecord(this.data.id)
        wx.showToast({ title: '已删除', icon: 'success' })
        setTimeout(() => wx.navigateBack(), 350)
      }
    })
  }
})
