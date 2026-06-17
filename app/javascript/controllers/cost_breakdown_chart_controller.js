import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = {
    labels: Array,
    amounts: Array
  }

  connect() {
    this.destroyChart()

    const chartData = this.chartData()

    if (chartData.amounts.length === 0) {
      return
    }

    this.chart = new Chart(this.element, {
      type: "pie",
      data: {
        labels: chartData.labels,
        datasets: [
          {
            data: chartData.amounts,
            backgroundColor: ["#0d6efd", "#20c997", "#ffc107", "#dc3545"],
            borderColor: "#ffffff",
            borderWidth: 2
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom"
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                const amount = this.currencyFormatter.format(context.parsed)

                return `${context.label}: ${amount}`
              }
            }
          }
        }
      }
    })
  }

  disconnect() {
    this.destroyChart()
  }

  chartData() {
    return this.amountsValue.reduce(
      (data, amount, index) => {
        const numericAmount = Number(amount)

        if (numericAmount > 0) {
          data.labels.push(this.labelsValue[index])
          data.amounts.push(numericAmount)
        }

        return data
      },
      { labels: [], amounts: [] }
    )
  }

  destroyChart() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  get currencyFormatter() {
    return new Intl.NumberFormat("ja-JP", {
      style: "currency",
      currency: "JPY",
      maximumFractionDigits: 0
    })
  }
}
