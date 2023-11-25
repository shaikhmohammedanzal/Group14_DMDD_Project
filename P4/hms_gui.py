import sys
from PyQt5.QtWidgets import QApplication, QMainWindow, QTableWidget, QTableWidgetItem, QVBoxLayout, QWidget, QPushButton, QLineEdit, QLabel, QMessageBox
import pyodbc

class HospitalManagementApp(QMainWindow):
    def __init__(self):
        super().__init__()

        # Connect to the database
        connection_string = (
            r"Driver={ODBC Driver 17 for SQL Server};"
            r"Server=Anzal\ANZALSQL;"
            r"Database=HospitalManagementSystem;"
            r"Trusted_Connection=yes;"
        )
        self.connection = pyodbc.connect(connection_string)

        # Set up the main window
        self.setWindowTitle("Hospital Management System")
        self.setGeometry(100, 100, 800, 600)

        # Create widgets
        self.create_widgets()

    def create_widgets(self):
        # Create table to display data
        self.table = QTableWidget(self)
        self.table.setColumnCount(4)  # Assuming 4 columns in the Ward table
        self.table.setHorizontalHeaderLabels(["Room_ID", "Bed_Number", "Ward_Type", "Floor_Number"])

        # Create input fields for adding and updating data
        self.bed_number_entry = QLineEdit(self)
        self.ward_type_entry = QLineEdit(self)
        self.floor_number_entry = QLineEdit(self)

        # Labels for input fields
        bed_number_label = QLabel("Bed Number:", self)
        ward_type_label = QLabel("Ward Type:", self)
        floor_number_label = QLabel("Floor Number:", self)

        # Create buttons for CRUD operations
        add_button = QPushButton("Add Ward", self)
        update_button = QPushButton("Update Ward", self)
        delete_button = QPushButton("Delete Ward", self)

        # Set up layout
        layout = QVBoxLayout()
        layout.addWidget(self.table)
        layout.addWidget(bed_number_label)
        layout.addWidget(self.bed_number_entry)
        layout.addWidget(ward_type_label)
        layout.addWidget(self.ward_type_entry)
        layout.addWidget(floor_number_label)
        layout.addWidget(self.floor_number_entry)
        layout.addWidget(add_button)
        layout.addWidget(update_button)
        layout.addWidget(delete_button)

        container = QWidget()
        container.setLayout(layout)
        self.setCentralWidget(container)

        # Connect buttons to functions
        add_button.clicked.connect(self.add_ward)
        update_button.clicked.connect(self.update_ward)
        delete_button.clicked.connect(self.delete_ward)

        # Load data on startup
        self.load_data()

    def load_data(self):
        try:
            cursor = self.connection.cursor()
            cursor.execute("SELECT * FROM Ward")
            rows = cursor.fetchall()

            # Clear existing data in the table
            self.table.setRowCount(0)

            # Insert new data into the table
            for row_num, row_data in enumerate(rows):
                self.table.insertRow(row_num)
                for col_num, col_data in enumerate(row_data):
                    item = QTableWidgetItem(str(col_data))
                    self.table.setItem(row_num, col_num, item)

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Error loading data: {str(e)}")
        finally:
            cursor.close()

    def add_ward(self):
        try:
            new_values = (
                self.bed_number_entry.text(),
                self.ward_type_entry.text(),
                self.floor_number_entry.text()
            )

            cursor = self.connection.cursor()
            cursor.execute(
                "INSERT INTO Ward (Bed_Number, Ward_Type, Floor_Number) VALUES (?, ?, ?)",
                new_values
            )
            self.connection.commit()

            # After adding, refresh the data
            self.load_data()

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Error adding ward: {str(e)}")

    def update_ward(self):
        selected_item = self.table.currentItem()
        if not selected_item:
            QMessageBox.warning(self, "Warning", "Please select a ward to update.")
            return

        row = selected_item.row()
        room_id = self.table.item(row, 0).text()  # Assuming Room_ID is in the first column
        new_values = (
            self.bed_number_entry.text(),
            self.ward_type_entry.text(),
            self.floor_number_entry.text()
        )

        try:
            cursor = self.connection.cursor()
            cursor.execute(
                "UPDATE Ward SET Bed_Number=?, Ward_Type=?, Floor_Number=? WHERE Room_ID=?",
                (*new_values, room_id)
            )
            self.connection.commit()

            # After updating, refresh the data
            self.load_data()

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Error updating ward: {str(e)}")

    def delete_ward(self):
        selected_item = self.table.currentItem()
        if not selected_item:
            QMessageBox.warning(self, "Warning", "Please select a ward to delete.")
            return

        row = selected_item.row()
        room_id = self.table.item(row, 0).text()  # Assuming Room_ID is in the first column

        try:
            cursor = self.connection.cursor()
            cursor.execute("DELETE FROM Ward WHERE Room_ID=?", room_id)
            self.connection.commit()

            # After deleting, refresh the data
            self.load_data()

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Error deleting ward: {str(e)}")


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = HospitalManagementApp()
    window.show()
    sys.exit(app.exec_())
