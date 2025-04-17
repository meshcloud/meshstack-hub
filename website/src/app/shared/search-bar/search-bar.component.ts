import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';

@Component({
  selector: 'mst-search-bar',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './search-bar.component.html',
  standalone: true
})
export class SearchBarComponent implements OnInit {
  public searchForm!: FormGroup;

  constructor(
    private router: Router,
    private fb: FormBuilder
  ) { }

  public ngOnInit(): void {
    this.initializeSearchForm();
  }

  public onSearch(): void {
    const searchTerm = this.searchForm.value.searchTerm;
    this.router.navigate(['/all'], {
      queryParams: { searchTerm }
    });
  }

  private initializeSearchForm(): void {
    this.searchForm = this.fb.group({
      searchTerm: ['']
    });
  }
}
