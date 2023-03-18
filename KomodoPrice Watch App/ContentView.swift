import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var priceFetcher = PriceFetcher()

    var body: some View {
        VStack {
            Text("KMD Price:")
                .font(.largeTitle)
                .padding(.bottom, 20)
            Text("$\(priceFetcher.price, specifier: "%.4f")")
                .font(.system(size: 40))
                .bold()
        }
        .padding()
        .onAppear {
            priceFetcher.fetchPrices()
        }
    }
}

struct Coin: Codable {
    let komodo: KMDPrice
}

struct KMDPrice: Codable {
    let usd: Double
}

struct KomodoLivePrice: Codable {
    let KMD: Ticker

    struct Ticker: Codable {
        let ticker: String
        let last_price: String
    }
}

class PriceFetcher: ObservableObject {
    @Published var price: Double = 0.0
    private var cancellable1: AnyCancellable?
    private var cancellable2: AnyCancellable?
    private var timerCancellable: AnyCancellable?

    private let url1 = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=komodo&vs_currencies=usd")!
    private let url2 = URL(string: "https://prices.komodo.live:1313/api/v2/tickers?expire_at=600")!

    init() {
        fetchPrices()
        timerCancellable = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchPrices()
            }
    }

    func fetchPrices() {
        cancellable1 = URLSession.shared.dataTaskPublisher(for: url1)
            .map { $0.data }
            .decode(type: Coin.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("Error fetching KMD price from CoinGecko: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] coin in
                self?.updatePrice(price1: coin.komodo.usd)
            })

        cancellable2 = URLSession.shared.dataTaskPublisher(for: url2)
            .map { $0.data }
            .decode(type: KomodoLivePrice.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("Error fetching KMD price from Komodo Live: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] komodoLivePrice in
                if let price2 = Double(komodoLivePrice.KMD.last_price) {
                    self?.updatePrice(price2: price2)
                }
            })
    }

    private var fetchedPrice1: Double?
    private var fetchedPrice2: Double?

    private func updatePrice(price1: Double? = nil, price2: Double? = nil) {
        if let price1 = price1 {
            fetchedPrice1 = price1
        }
        if let price2 = price2 {
            fetchedPrice2 = price2
        }

        if let price1 = fetchedPrice1, let price2 = fetchedPrice2 {
            price = (price1 + price2) / 2
        }
    }

    deinit {
        timerCancellable?.cancel()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
