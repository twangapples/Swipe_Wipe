import SwiftUI
import PhotosUI
import CoreHaptics

enum PhotoCategory: Hashable {
    case screenshots
    case recents
    case random
    case year(Int)  // Example: .year(2023)
    case month(Int, Int)  // Example: .month(2023, 5) for May 2023
}

func getMonthName(_ month: Int) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM" // Full month name (e.g., "January")
    return formatter.string(from: Calendar.current.date(from: DateComponents(month: month))!)
}

struct ContentView: View {
    @State private var keptPhotos: [PhotoCategory: Int] = [:]  // ✅ Track "Keep" count per category
    @State private var deletedPhotosCount: [PhotoCategory: Int] = [:]  // ✅ Track "Delete" count per category
    @State private var selectedYear: Int? = nil  // Stores the selected year
    @State private var images: [PHAsset] = []
    @State private var currentIndex = 0
    @State private var showingReview = false
    @State private var dragOffset: CGFloat = 0
    @State private var selectedCategory: PhotoCategory? = nil // Allows returning to category selection
    @State private var navigatingToMonthSelection = false  // Track navigation
    @State private var deletedPhotos: [PhotoCategory: [PHAsset]] = [:]  // Track deleted photos separately per category
    @State private var progressTracker: [PhotoCategory: Int] = [:]  // ✅ Store last swiped index per category
    @State private var completedMonths: [PhotoCategory: Bool] = [:]  // ✅ Track completed months
    @State private var swipeStack: [(index: Int, direction: String)] = [] // Stack storing swipe history




    var body: some View {
        VStack {
            if let selectedCategory = selectedCategory {
                
                // Back button
                HStack {
                    // Back Button - Top Left
                    Button(action: { resetToCategorySelection() }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                            .padding()
                    }
                    .padding(.leading, 20)

                    Spacer()

                    // Counter - Top Right
                    Text("\(currentIndex + 1) / \(images.count)")
                        .font(.headline)
                        .foregroundColor(.white)
                        //.padding(8)
                        .padding(.trailing, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 35) // ✅ Pushes it below the status bar
                Spacer()
                                
                // Swiping UI
                ZStack {
                    if images.indices.contains(currentIndex) {
                        ReviewImageView(asset: images[currentIndex])
                            .id(currentIndex)
                            .offset(x: dragOffset) // ✅ Moves the image with swipe
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = value.translation.width // ✅ Track swipe movement
                                    }
                                    .onEnded { value in
                                        if value.translation.width < -100 {
                                            withAnimation(.spring()) {
                                                deletePhoto()
                                                triggerHapticFeedback() // ✅ Haptic feedback when deleting
                                                dragOffset = 0 // ✅ Reset after transition
                                                swipeStack.append((currentIndex, "left")) // ✅ Push to stack
                                            }
                                        } else if value.translation.width > 100 {
                                            withAnimation(.spring()) {
                                                keepPhoto()
                                                triggerHapticFeedback() // ✅ Haptic feedback when keeping
                                                dragOffset = 0 // ✅ Reset after transition
                                                swipeStack.append((currentIndex, "right")) // ✅ Push to stack

                                            }
                                        } else {
                                            withAnimation {
                                                dragOffset = 0 // ✅ Snap back if swipe isn't far enough
                                            }
                                        }
                                    }
                            )
                            .rotationEffect(.degrees(dragOffset / 20)) // ✅ Tilts image slightly based on swipe
                            .onTapGesture {
                                undoLastSwipe()
                            }
                    }
                }

                Spacer()

                // Delete and Keep counters
                HStack {
                    // "Delete" Label + Counter
                    VStack {
                        Text("Delete")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Text("\(deletedPhotosCount[selectedCategory] ?? 0)") // ✅ Show category-specific count
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .padding(.leading,20)
                    
                    Spacer()
                    
                    // "Review Deleted Photos" Button (Smaller)
                    Button(action: { showingReview = true }) {
                        Text("Review Deleted Photos")
                            .font(.subheadline) // ✅ Smaller font size
                            .foregroundColor(.white)
                            .padding(8) // ✅ Less padding to reduce overall size
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8) // ✅ Smaller corner radius
                                    .stroke(Color.white, lineWidth: 1.5) // ✅ Thinner border
                            )
                    }

                    Spacer()

                    // "Keep" Label + Counter
                    VStack {
                        Text("Keep")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Text("\(keptPhotos[selectedCategory] ?? 0)") // ✅ Show category-specific count
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                    .padding(.trailing, 20)

                }
                .padding(.bottom, 30) // ✅ Slightly reduced padding

                .sheet(isPresented: $showingReview) {
                    ReviewPhotosView(
                        deletedPhotos: Binding(
                            get: { deletedPhotos[selectedCategory ?? .recents] ?? [] },
                            set: { deletedPhotos[selectedCategory ?? .recents] = $0 }
                        ),
                        completedMonths: $completedMonths, // ✅ Pass completedMonths
                        showingReview: $showingReview,
                        selectedCategory: $selectedCategory  // ✅ Now passed as a binding
                    )
                }




            }
            else {
                // Category selection
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 20) {
                            Text("Select a Category")
                                .font(.headline)
                                .padding(.top)
                            
                            
                            Button("Screenshots") {
                                selectedCategory = .screenshots
                                fetchPhotos(for: .screenshots)
                            }
                            .buttonStyle(CategoryButtonStyle())

                            Button("Recents") {
                                selectedCategory = .recents
                                fetchPhotos(for: .recents)
                            }
                            .buttonStyle(CategoryButtonStyle())



                            ForEach(getAvailableYears(), id: \.self) { year in
                                NavigationLink(destination: MonthSelectionView(
                                    year: year,
                                    selectedCategory: $selectedCategory,
                                    fetchPhotos: fetchPhotos,
                                    completedMonths: $completedMonths  // ✅ Pass completedMonths as a binding
                                )) {
                                    Text("\(String(year))") // ✅ Also works
                                        .font(.title2)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .padding(.horizontal, 40)
                                }
                            }
                        }
                        .padding()
                    }
                }

                .navigationDestination(isPresented: $navigatingToMonthSelection) {
                    if let selectedYear = selectedYear {
                        MonthSelectionView(
                            year: selectedYear,
                            selectedCategory: $selectedCategory,  // ✅ Pass as Binding
                            fetchPhotos: fetchPhotos,  // ✅ Pass function reference
                            completedMonths: $completedMonths  // ✅ FIX: Add this argument
                        )
                    }
                }
            }
        }
    }

    func selectCategory(_ category: PhotoCategory) {
        selectedCategory = category
        fetchPhotos(for: category)
    }
    func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func resetToCategorySelection() {
        selectedCategory = nil
        images.removeAll()
        currentIndex = 0
    }

    func fetchPhotos(for category: PhotoCategory) {
        // ✅ Restore previous progress if available
        if let savedIndex = progressTracker[category] {
            currentIndex = savedIndex  // ✅ Keep the same index as last time
        } else {
            currentIndex = 0  // ✅ Default to first image if no saved progress
        }
        
        
        // ✅ Save progress before switching
        if let currentCategory = selectedCategory {
            progressTracker[currentCategory] = currentIndex  // Store last swiped position
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 100  // ✅ Limit to the 100 most recent photos
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var selectedYear: Int? = nil
        var selectedMonth: Int? = nil

        // ✅ Extract year and month from the category
        switch category {
            
        case .screenshots:
            fetchOptions.predicate = NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoScreenshot.rawValue)
            images = PHAsset.fetchAssets(with: .image, options: fetchOptions).objects(at: IndexSet(0..<min(100, PHAsset.fetchAssets(with: .image, options: fetchOptions).count)))


        case .recents:
            images = PHAsset.fetchAssets(with: .image, options: fetchOptions).objects(at: IndexSet(0..<min(100, PHAsset.fetchAssets(with: .image, options: fetchOptions).count)))
        case .year(let year):
            selectedYear = year
        case .month(let year, let month):
            selectedYear = year
            selectedMonth = month
        default:
            break
        }

        images = (0..<assets.count).compactMap { index in
            let asset = assets.object(at: index)

        
            if let creationDate = asset.creationDate {
                let calendar = Calendar.current
                let year = calendar.component(.year, from: creationDate)
                let month = calendar.component(.month, from: creationDate)
                
                // ✅ Filter correctly based on year and month
                if let selectedYear = selectedYear {
                    if category == .year(selectedYear) {
                        return year == selectedYear ? asset : nil
                    } else if let selectedMonth = selectedMonth {
                        return (year == selectedYear && month == selectedMonth) ? asset : nil
                    }
                }
            }
            let isDeleted = deletedPhotos[category]?.contains(where: { $0.localIdentifier == asset.localIdentifier }) ?? false

            return asset  // ✅ Keep deleted photos in the list but track their status separately

        }




        // ✅ Update progressTracker immediately after restoring
        progressTracker[category] = currentIndex
        print("Returning to category: \(category)")
        print("Restored index: \(currentIndex)")
        print("Total images in category: \(images.count)")
        print("Progress tracker stored: \(progressTracker[category] ?? 0)")

    }





    func keepPhoto() {
        guard let category = selectedCategory else { return }

        // ✅ Update keep count for this category
        if let count = keptPhotos[category] {
            keptPhotos[category] = count + 1
        } else {
            keptPhotos[category] = 1
        }

        nextImage()
    }

    func deletePhoto() {
        guard let category = selectedCategory else { return }

        // ✅ Track deleted photos for this category
        if var deletedList = deletedPhotos[category] {
            deletedList.append(images[currentIndex])
            deletedPhotos[category] = deletedList
        } else {
            deletedPhotos[category] = [images[currentIndex]]
        }

        // ✅ Update delete count for this category
        if let count = deletedPhotosCount[category] {
            deletedPhotosCount[category] = count + 1
        } else {
            deletedPhotosCount[category] = 1
        }

        nextImage()
    }





    func nextImage() {
        if currentIndex < images.count - 1 {
            currentIndex += 1
        } else {
            // ✅ User has swiped through all photos, open Review Photos View
            showingReview = true
        }
        progressTracker[selectedCategory ?? .recents] = currentIndex  // ✅ Always update the tracker
    }

    func undoLastSwipe() {
        guard let lastSwipe = swipeStack.popLast(), let category = selectedCategory else { return }

        let lastIndex = lastSwipe.index
        let lastDirection = lastSwipe.direction
        
        if currentIndex > 0 {
            currentIndex -= 1
        }

        progressTracker[category] = currentIndex


        let lastImage = images[currentIndex]

        if var deletedList = deletedPhotos[category] {
            if let index = deletedList.firstIndex(where: { $0.localIdentifier == lastImage.localIdentifier }) {
                
                let restoredPhoto = deletedList.remove(at: index)  // ✅ Remove from list
                deletedPhotos[category] = deletedList  // ✅ Save back to dictionary

                if let count = deletedPhotosCount[category], count > 0 {
                    deletedPhotosCount[category] = count - 1  // ✅ Update deleted counter
                    currentIndex -= 1

                }


                if currentIndex > 0 {
                    currentIndex -= 1  // ✅ Move back to correct index
                print("current Index" , currentIndex)
                }
            }
        }
        else if let count = keptPhotos[category], count > 0 {
            keptPhotos[category] = count - 1
            currentIndex -= 1
        }

        // ✅ Force UI update so the counter updates immediately
        currentIndex = max(0, currentIndex)

        // ✅ Haptic feedback
        DispatchQueue.main.async {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }

        // ✅ Undo animation
        dragOffset = (lastDirection == "left") ? -UIScreen.main.bounds.width : UIScreen.main.bounds.width
        withAnimation(.spring()) {
            dragOffset = 0
        }
    }



    func getAvailableYears() -> [Int] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var years: Set<Int> = []
        let calendar = Calendar.current

        (0..<assets.count).forEach { index in
            if let creationDate = assets.object(at: index).creationDate {
                let year = calendar.component(.year, from: creationDate)
                years.insert(year)
            }
        }

        return years.sorted(by: >)  // ✅ Still an Int, but formatted correctly later
    }
}

struct MonthSelectionView: View {
    let year: Int
    @Binding var selectedCategory: PhotoCategory?
    let fetchPhotos: (PhotoCategory) -> Void
    @Binding var completedMonths: [PhotoCategory: Bool]  // ✅ Track completed months

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Select a Month for \(year)")
                    .font(.headline)
                    .padding(.top)

                ForEach(1...12, id: \.self) { month in
                    Button(action: {
                        selectedCategory = .month(year, month)
                        fetchPhotos(.month(year, month))
                    }) {
                        HStack {
                            Text("\(getMonthName(month))")  // ✅ Month name
                                .font(.title2)
                                .padding()

                            // ✅ Add a checkmark if the month is completed
                            if completedMonths[.month(year, month)] == true {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                    }
                }
            }
            .navigationTitle("\(year)")  // ✅ Shows the selected year in the navigation bar
            .padding()
        }
    }
}




// Displays Deleted Photos
struct ReviewPhotosView: View {
    @Binding var deletedPhotos: [PHAsset]
    @Binding var completedMonths: [PhotoCategory: Bool]  // ✅ Track completed months
    @Binding var showingReview: Bool
    @Binding var selectedCategory: PhotoCategory?

    @State private var showingDeleteConfirmation = false

    let columns = [
        GridItem(.adaptive(minimum: 100))
    ]

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(deletedPhotos, id: \.localIdentifier) { asset in
                            VStack {
                                ReviewImageView(asset: asset)
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)

                                Button(action: {
                                    restorePhoto(asset)  // ✅ Restore function now works
                                }) {
                                    Text("Restore")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(5)
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(5)
                                }
                            }
                        }
                    }
                    .padding()
                }

                // ✅ "Delete All Permanently" Button
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Text("Delete All Permanently")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(deletedPhotos.isEmpty ? Color.gray : Color.red)
                        .cornerRadius(10)
                }
                .disabled(deletedPhotos.isEmpty)
                .padding()
                .alert(isPresented: $showingDeleteConfirmation) {
                    Alert(
                        title: Text("Permanently Delete All?"),
                        message: Text("This action cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            deleteAllPhotos()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .navigationTitle("Review Deleted Photos")
        }
    }

    // ✅ Restore a Photo (Removes from Deleted List)
    private func restorePhoto(_ asset: PHAsset) {
        deletedPhotos.removeAll { $0.localIdentifier == asset.localIdentifier }
    }

    // ✅ Delete All Photos Permanently
    private func deleteAllPhotos() {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(deletedPhotos as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Deleted all photos permanently.")

                    // ✅ Clear the deleted list
                    deletedPhotos.removeAll()

                    // ✅ Close the sheet and return to main menu
                    showingReview = false

                    // ✅ Reset counter if this category was fully processed
                    if let category = selectedCategory {
                        completedMonths[category] = true  // ✅ Mark month as completed
                    }
                } else if let error = error {
                    print("❌ Error deleting photos: \(error.localizedDescription)")
                }
            }
        }
    }

}




// Displays a Single Image
struct ReviewImageView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            } else {
                ProgressView()
                    .onAppear { loadPhoto() }
            }
        }
        .id(asset.localIdentifier)
    }

    func loadPhoto() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        let targetSize = CGSize(width: UIScreen.main.bounds.width * 2, height: UIScreen.main.bounds.height * 2)

        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { result, _ in
            DispatchQueue.main.async { image = result }
        }
    }
}

// Button Styling
struct CategoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(configuration.isPressed ? 0.6 : 1.0))
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal, 40)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

