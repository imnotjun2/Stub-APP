const store = require('../../utils/archive-store')

Page({
  data: {
    trips: [],
    primaryTrip: null
  },

  onShow() {
    const archive = store.getArchive()
    const trips = archive.trips.map((trip) => ({
      ...trip,
      count: archive.placements.filter((placement) => placement.tripId === trip.id).length,
      dateRange: `${trip.startDate.replace(/-/g, '.')} — ${trip.endDate.replace(/-/g, '.')}`
    }))
    this.setData({ trips, primaryTrip: trips[0] || null })
  },

  openEditor() {
    wx.navigateTo({ url: '/pages/editor/index' })
  },

  openTrip(event) {
    const id = event.currentTarget.dataset.id
    wx.navigateTo({ url: `/pages/trip-detail/index?id=${encodeURIComponent(id)}` })
  }
})
