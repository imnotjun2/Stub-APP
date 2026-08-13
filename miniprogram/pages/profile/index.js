const store = require('../../utils/archive-store')

Page({
  data: {
    recordCount: 0,
    userCount: 0,
    tripCount: 0
  },

  onShow() {
    this.reload()
  },

  reload() {
    const archive = store.getArchive()
    this.setData({
      recordCount: archive.records.length,
      userCount: archive.records.filter((record) => record.source === 'user').length,
      tripCount: archive.trips.length
    })
  },

  resetDemo() {
    wx.showModal({
      title: '恢复初始 Demo？',
      content: '你上传到本地的票据照片和记录会被删除，示例数据会恢复。',
      confirmText: '恢复',
      confirmColor: '#9F342F',
      success: (result) => {
        if (!result.confirm) return
        store.resetArchive()
        this.reload()
        wx.showToast({ title: 'Demo 已恢复', icon: 'success' })
      }
    })
  }
})
