import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var priceFetcher = PriceFetcher()

    var body: some View {
        VStack {
            Text("KMD Price")
                .font(.largeTitle)
            Text("\(priceFetcher.price, specifier: "%.5f") USD")
                .font(.title)
                .padding()
        }
        .onAppear {
            priceFetcher.fetchPrice()
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
    private var cancellable: AnyCancellable?
    private var timerCancellable: AnyCancellable?

    private let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=komodo&vs_currencies=usd")!

    init() {
        fetchPrice()
        timerCancellable = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchPrice()
            }
    }

    func fetchPrice() {
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: Coin.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("Error fetching KMD price: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] coin in
                self?.price = coin.komodo.usd
            })
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
