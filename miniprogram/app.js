const archiveStore = require('./utils/archive-store')

App({
  onLaunch() {
    archiveStore.ensureArchive()
  },
  globalData: {
    productName: 'Stub',
    productSubtitle: '生活存根'
  }
})
